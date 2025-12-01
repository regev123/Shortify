package com.shortify.lookup.service;

import com.shortify.lookup.repository.LookupUrlRepository;
import com.shortify.entity.UrlMapping;
import com.shortify.event.UrlDeletedEvent;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.LocalDateTime;
import java.util.List;
import java.util.concurrent.CompletableFuture;

/**
 * Service for cleaning up unused URLs
 * Part of the Lookup Service microservice architecture
 * 
 * Follows Single Responsibility Principle - only handles URL cleanup operations
 * Follows Open/Closed Principle - configurable retention period via properties
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class UrlCleanupService {
    
    private final LookupUrlRepository urlMappingRepository;
    private final KafkaTemplate<String, Object> kafkaTemplate;
    
    @Value("${url.cleanup.retention-months:6}")
    private int retentionMonths;
    
    @Value("${url.cleanup.enabled:true}")
    private boolean cleanupEnabled;
    
    @Value("${url.cleanup.batch-size:1000}")
    private int batchSize;
    
    @Value("${kafka.topic.url-deleted:url-deleted-events}")
    private String urlDeletedTopic;
    
    /**
     * Scheduled cleanup job that runs daily at 2 AM
     * Deletes URLs that:
     * 1. Haven't been accessed in the configured retention period (6 months by default)
     * 2. Have expired (expiresAt < now)
     * 
     * Cron expression: "0 0 2 * * ?" = Every day at 2:00 AM
     * 
     * Note: Each batch deletion runs in its own transaction to avoid long-running transactions
     * and prevent connection pool exhaustion. The sleep between batches happens outside transactions.
     */
    @Scheduled(cron = "${url.cleanup.cron:0 0 2 * * ?}")
    public void cleanupUnusedUrls() {
        if (!cleanupEnabled) {
            return;
        }
        
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime accessCutoffDate = now.minusMonths(retentionMonths);
        
        try {
            // Delete in batches, each batch in its own transaction
            // This prevents long-running transactions and connection pool exhaustion
            boolean hasMore = true;
            while (hasMore) {
                List<String> deletedShortCodes = deleteBatch(accessCutoffDate, now);
                
                // Publish deletion events to Kafka for stats service cleanup
                publishDeletionEvents(deletedShortCodes, now);
                
                if (deletedShortCodes.size() < batchSize) {
                    hasMore = false;
                } else {
                    // Small delay between batches to avoid overwhelming the database
                    // Sleep happens OUTSIDE transaction to avoid holding connections
                    Thread.sleep(100);
                }
            }
            
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            log.error("URL cleanup job interrupted", e);
        } catch (Exception e) {
            log.error("Error during URL cleanup job", e);
            // Don't re-throw - allow job to continue next time
            // Logging the error is sufficient for scheduled jobs
        }
    }
    
    /**
     * Deletes a single batch of URLs in its own transaction
     * Uses REQUIRES_NEW propagation to ensure each batch is independent
     * 
     * @param accessCutoffDate cutoff date for access-based deletion
     * @param currentTime current time for expiration check
     * @return list of shortCodes that were deleted
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    private List<String> deleteBatch(LocalDateTime accessCutoffDate, LocalDateTime currentTime) {
        // First, get the URLs that will be deleted (to get their shortCodes)
        List<UrlMapping> urlsToDelete = urlMappingRepository.findUnusedOrExpiredUrls(
                accessCutoffDate, currentTime, batchSize);
        
        // Extract shortCodes before deletion
        List<String> shortCodes = urlsToDelete.stream()
                .map(UrlMapping::getShortUrl)
                .toList();
        
        // Delete the URLs
        if (!shortCodes.isEmpty()) {
            urlMappingRepository.deleteUnusedOrExpiredUrls(accessCutoffDate, currentTime, batchSize);
        }
        
        return shortCodes;
    }
    
    /**
     * Publish URL deletion events to Kafka for stats service cleanup.
     * Events are sent asynchronously to avoid blocking the cleanup job.
     */
    private void publishDeletionEvents(List<String> deletedShortCodes, LocalDateTime deletionTime) {
        if (deletedShortCodes.isEmpty()) {
            return;
        }
        
        long timestamp = Instant.now().toEpochMilli();
        
        for (String shortCode : deletedShortCodes) {
            try {
                // Determine deletion reason based on expiration
                String reason = deletionTime.isAfter(LocalDateTime.now()) ? "UNUSED" : "EXPIRED";
                
                UrlDeletedEvent event = UrlDeletedEvent.builder()
                        .shortCode(shortCode)
                        .reason(reason)
                        .timestamp(timestamp)
                        .build();
                
                // Send to Kafka asynchronously
                CompletableFuture<?> future = kafkaTemplate.send(urlDeletedTopic, shortCode, event);
                
                future.whenComplete((result, ex) -> {
                    if (ex == null) {
                        log.debug("Published URL deletion event for shortCode: {}", shortCode);
                    } else {
                        log.warn("Failed to publish URL deletion event for shortCode: {}", shortCode, ex);
                        // Event is lost, but cleanup continues
                        // In production, consider implementing a dead letter queue
                    }
                });
            } catch (Exception e) {
                log.warn("Error publishing deletion event for shortCode: {}", shortCode, e);
                // Don't fail cleanup if Kafka is unavailable
            }
        }
        
        log.debug("Published {} URL deletion events to Kafka", deletedShortCodes.size());
    }
    
    /**
     * Manual cleanup method for testing or ad-hoc execution
     * 
     * @return number of URLs deleted
     */
    @Transactional
    public long cleanupUnusedUrlsManually() {
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime accessCutoffDate = now.minusMonths(retentionMonths);
        return urlMappingRepository.deleteUnusedOrExpiredUrls(accessCutoffDate, now, Integer.MAX_VALUE);
    }
}

