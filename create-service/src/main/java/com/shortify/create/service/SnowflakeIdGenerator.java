package com.shortify.create.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.time.Instant;

/**
 * Snowflake ID Generator for distributed unique ID generation
 * 
 * Based on Twitter's Snowflake algorithm:
 * - 64-bit ID structure:
 *   - 41 bits: timestamp (milliseconds since custom epoch)
 *   - 10 bits: machine ID (5 bits datacenter + 5 bits worker)
 *   - 12 bits: sequence number (4096 IDs/ms per machine)
 * 
 * Capacity: 4096 IDs/ms × 1000ms/sec × 1024 machines = 4.2B IDs/sec
 * 
 * Follows Single Responsibility Principle - only handles ID generation
 * Thread-safe implementation for concurrent access
 */
@Slf4j
@Component
public class SnowflakeIdGenerator {
    
    // Bit allocation
    private static final long SEQUENCE_BITS = 12L;
    private static final long WORKER_ID_BITS = 5L;
    private static final long DATACENTER_ID_BITS = 5L;
    
    // Maximum values
    private static final long MAX_WORKER_ID = (1L << WORKER_ID_BITS) - 1; // 31
    private static final long MAX_DATACENTER_ID = (1L << DATACENTER_ID_BITS) - 1; // 31
    private static final long MAX_SEQUENCE = (1L << SEQUENCE_BITS) - 1; // 4095
    
    // Bit shifts
    private static final long WORKER_ID_SHIFT = SEQUENCE_BITS;
    private static final long DATACENTER_ID_SHIFT = SEQUENCE_BITS + WORKER_ID_BITS;
    private static final long TIMESTAMP_SHIFT = SEQUENCE_BITS + WORKER_ID_BITS + DATACENTER_ID_BITS;
    
    // Custom epoch (2024-12-01 00:00:00 UTC) - starts IDs small for 6-character codes
    // This ensures first IDs encode to 6 characters and grow naturally over time
    // As time passes, IDs will automatically grow to 7, 8, 9, 10, 11 characters
    private static final long CUSTOM_EPOCH = 1733011200000L; // 2024-12-01 00:00:00 UTC
    
    // Instance variables
    private final long workerId;
    private final long datacenterId;
    private long sequence = 0L;
    private long lastTimestamp = -1L;
    
    /**
     * Constructor with configuration values
     * 
     * @param workerId Worker ID (0-31) - unique per instance
     * @param datacenterId Datacenter ID (0-31) - unique per datacenter
     */
    public SnowflakeIdGenerator(
            @Value("${snowflake.worker-id:1}") long workerId,
            @Value("${snowflake.datacenter-id:1}") long datacenterId) {
        
        // Validate worker ID
        if (workerId < 0 || workerId > MAX_WORKER_ID) {
            throw new IllegalArgumentException(
                String.format("Worker ID must be between 0 and %d, got: %d", MAX_WORKER_ID, workerId)
            );
        }
        
        // Validate datacenter ID
        if (datacenterId < 0 || datacenterId > MAX_DATACENTER_ID) {
            throw new IllegalArgumentException(
                String.format("Datacenter ID must be between 0 and %d, got: %d", MAX_DATACENTER_ID, datacenterId)
            );
        }
        
        this.workerId = workerId;
        this.datacenterId = datacenterId;
        
        log.info("Snowflake ID Generator initialized - Worker ID: {}, Datacenter ID: {}", workerId, datacenterId);
    }
    
    /**
     * Generates a unique 64-bit ID
     * Thread-safe implementation using synchronized block
     * 
     * @return unique 64-bit ID
     * @throws RuntimeException if clock moves backward or sequence overflows
     */
    public synchronized long generateId() {
        long timestamp = currentTimestamp();
        
        // Handle clock moving backward
        if (timestamp < lastTimestamp) {
            long offset = lastTimestamp - timestamp;
            log.error("Clock moved backward by {} milliseconds. Refusing to generate ID.", offset);
            throw new RuntimeException(
                String.format("Clock moved backward. Refusing to generate ID for %d milliseconds", offset)
            );
        }
        
        // Same millisecond - increment sequence
        if (timestamp == lastTimestamp) {
            sequence = (sequence + 1) & MAX_SEQUENCE;
            
            // Sequence overflow - wait for next millisecond
            if (sequence == 0) {
                timestamp = waitNextMillis(lastTimestamp);
            }
        } else {
            // New millisecond - reset sequence
            sequence = 0L;
        }
        
        lastTimestamp = timestamp;
        
        // Build ID: timestamp | datacenter | worker | sequence
        long id = ((timestamp - CUSTOM_EPOCH) << TIMESTAMP_SHIFT)
                | (datacenterId << DATACENTER_ID_SHIFT)
                | (workerId << WORKER_ID_SHIFT)
                | sequence;
        
        log.debug("Generated Snowflake ID: {} (timestamp: {}, datacenter: {}, worker: {}, sequence: {})",
                id, timestamp, datacenterId, workerId, sequence);
        
        return id;
    }
    
    /**
     * Gets current timestamp in milliseconds
     * 
     * @return current timestamp
     */
    private long currentTimestamp() {
        return Instant.now().toEpochMilli();
    }
    
    /**
     * Waits until next millisecond if sequence overflow occurs
     * 
     * @param lastTimestamp last timestamp used
     * @return next available timestamp
     */
    private long waitNextMillis(long lastTimestamp) {
        long timestamp = currentTimestamp();
        while (timestamp <= lastTimestamp) {
            timestamp = currentTimestamp();
        }
        return timestamp;
    }
    
    /**
     * Gets the worker ID
     * 
     * @return worker ID
     */
    public long getWorkerId() {
        return workerId;
    }
    
    /**
     * Gets the datacenter ID
     * 
     * @return datacenter ID
     */
    public long getDatacenterId() {
        return datacenterId;
    }
}

