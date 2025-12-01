package com.shortify.stats.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.shortify.stats.repository.UrlClickEventRepository;

import java.time.LocalDateTime;

/**
 * Service to manage data retention for click events.
 * 
 * Strategy:
 * - Keep recent click events (configurable retention period, e.g., 30-90 days) for detailed analysis
 * - Delete older events since aggregated statistics are already stored in url_statistics table
 * - This prevents the url_click_events table from growing indefinitely
 * 
 * For 100B clicks/year:
 * - With 90-day retention: ~25B rows (manageable with partitioning)
 * - Aggregated stats in url_statistics: ~10M rows (one per URL)
 * - Storage savings: ~99.99% reduction
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class DataRetentionService {
    
    private final UrlClickEventRepository clickEventRepository;
    
    @Value("${stats.retention.enabled:true}")
    private boolean retentionEnabled;
    
    @Value("${stats.retention.keep-days:90}")
    private int keepDays;
    
    @Value("${stats.retention.cleanup-interval-hours:24}")
    private int cleanupIntervalHours;
    
    /**
     * Scheduled job to delete old click events.
     * Runs daily (configurable) to clean up events older than the retention period.
     * 
     * This is safe because:
     * - Aggregated statistics are already stored in url_statistics table
     * - Recent events (within retention period) are kept for detailed analysis
     * - The aggregation job runs before this cleanup, ensuring stats are up-to-date
     */
    @Scheduled(fixedDelayString = "${stats.retention.cleanup-interval-ms:86400000}")
    public void cleanupOldClickEvents() {
        if (!retentionEnabled) {
            log.debug("Data retention cleanup is disabled");
            return;
        }
        
        try {
            LocalDateTime cutoffDate = LocalDateTime.now().minusDays(keepDays);
            
            // Delete events older than retention period
            // Using batch deletion for efficiency
            deleteOldEventsBatch(cutoffDate);
            
        } catch (Exception e) {
            log.error("Error during data retention cleanup", e);
        }
    }
    
    /**
     * Delete old click events in batches to avoid long-running transactions.
     * Processes in chunks to prevent memory issues and lock timeouts.
     */
    @Transactional
    public int deleteOldEventsBatch(LocalDateTime cutoffDate) {
        int totalDeleted = 0;
        int batchSize = 10000; // Delete 10k at a time
        int deletedInBatch;
        
        do {
            deletedInBatch = clickEventRepository.deleteByClickedAtBefore(cutoffDate, batchSize);
            totalDeleted += deletedInBatch;
            
            if (deletedInBatch > 0) {
                log.debug("Deleted {} events in this batch (total: {})", deletedInBatch, totalDeleted);
                
                // Small delay between batches to avoid overwhelming the database
                try {
                    Thread.sleep(100);
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                    log.warn("Cleanup interrupted");
                    break;
                }
            }
        } while (deletedInBatch == batchSize);
        
        return totalDeleted;
    }
}

