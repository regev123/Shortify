package com.shortify.stats.controller;

import com.shortify.stats.dto.ClickEventRequest;
import com.shortify.stats.dto.PlatformStatisticsResponse;
import com.shortify.stats.dto.UrlStatisticsResponse;
import com.shortify.stats.service.StatsService;
import com.shortify.event.ClickEvent;
import com.shortify.event.UrlDeletedEvent;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.support.Acknowledgment;
import org.springframework.kafka.support.KafkaHeaders;
import org.springframework.messaging.handler.annotation.Header;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/stats")
@RequiredArgsConstructor
@Slf4j
public class StatsController {
    
    private final StatsService statsService;
    
    /**
     * Kafka consumer for click events (batch processing enabled)
     * Processes events from the url-click-events topic in batches for high throughput
     */
    @KafkaListener(topics = "${kafka.topic.click-events:url-click-events}", 
                   containerFactory = "kafkaListenerContainerFactory")
    public void consumeClickEvents(
            @Payload List<ClickEvent> events,
            @Header(KafkaHeaders.RECEIVED_KEY) List<String> keys,
            Acknowledgment acknowledgment) {
        try {
            log.debug("Received batch of {} click events from Kafka", events.size());
            
            // Process all events in the batch
            for (ClickEvent event : events) {
                // Convert ClickEvent to ClickEventRequest
                ClickEventRequest request = 
                        ClickEventRequest.builder()
                                .shortCode(event.getShortCode())
                                .ipAddress(event.getIpAddress())
                                .userAgent(event.getUserAgent())
                                .referrer(event.getReferrer())
                                .country(event.getCountry())
                                .city(event.getCity())
                                .deviceType(event.getDeviceType())
                                .build();
                
                statsService.recordClickEvent(request);
            }
            
            // Acknowledge entire batch after processing
            acknowledgment.acknowledge();
            log.debug("Successfully processed batch of {} click events", events.size());
        } catch (Exception e) {
            log.error("Error processing click event batch (size: {})", events.size(), e);
            // In production, consider sending to dead letter queue instead of acknowledging
            // For now, we acknowledge to prevent blocking the consumer
            acknowledgment.acknowledge();
        }
    }
    
    /**
     * Kafka consumer for URL deletion events.
     * When URLs are deleted from the main database, this cleans up their statistics.
     * Processes events in batches for efficiency.
     */
    @KafkaListener(topics = "${kafka.topic.url-deleted:url-deleted-events}", 
                   containerFactory = "kafkaListenerContainerFactory")
    public void consumeUrlDeletedEvents(
            @Payload List<UrlDeletedEvent> events,
            @Header(KafkaHeaders.RECEIVED_KEY) List<String> keys,
            Acknowledgment acknowledgment) {
        try {
            // Process all deletion events in the batch
            for (UrlDeletedEvent event : events) {
                statsService.deleteStatisticsForUrl(event.getShortCode());
                log.debug("Deleted statistics for shortCode: {} (reason: {})", 
                        event.getShortCode(), event.getReason());
            }
            
            // Acknowledge entire batch after processing
            acknowledgment.acknowledge();
        } catch (Exception e) {
            log.error("Error processing URL deletion event batch (size: {})", events.size(), e);
            // In production, consider sending to dead letter queue instead of acknowledging
            // For now, we acknowledge to prevent blocking the consumer
            acknowledgment.acknowledge();
        }
    }
    
    @GetMapping("/url/{shortCode}")
    public ResponseEntity<UrlStatisticsResponse> getUrlStatistics(@PathVariable("shortCode") String shortCode) {
        log.debug("Getting statistics for shortCode: {}", shortCode);
        UrlStatisticsResponse response = statsService.getUrlStatistics(shortCode);
        return ResponseEntity.ok(response);
    }
    
    @GetMapping("/platform")
    public ResponseEntity<PlatformStatisticsResponse> getPlatformStatistics() {
        log.debug("Getting platform statistics");
        PlatformStatisticsResponse response = statsService.getPlatformStatistics();
        return ResponseEntity.ok(response);
    }
}

