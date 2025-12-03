package com.shortify.create.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;

/**
 * Service for managing database partitions
 * Automatically creates partitions for future months and manages partition lifecycle
 * 
 * Follows Single Responsibility Principle - only handles partition management
 * Follows Open/Closed Principle - extensible for different partition strategies
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class PartitionManagementService {
    
    private final JdbcTemplate jdbcTemplate;
    private static final DateTimeFormatter PARTITION_DATE_FORMAT = DateTimeFormatter.ofPattern("yyyy_MM");
    
    /**
     * Creates the next month's partition if it doesn't exist
     * This ensures partitions are always available before they're needed
     * 
     * Scheduled to run on the 25th of each month at 2 AM
     * Safe to run even if partition was already created on startup
     */
    @Scheduled(cron = "0 0 2 25 * ?")  // 25th of each month at 2 AM
    public void createNextMonthPartition() {
        try {
            log.info("Scheduled task: Creating next month's partition...");
            
            LocalDate nextMonth = LocalDate.now().plusMonths(1);
            LocalDate startDate = nextMonth.withDayOfMonth(1);
            LocalDate endDate = startDate.plusMonths(1);
            String partitionName = "url_mappings_" + startDate.format(PARTITION_DATE_FORMAT);
            
            // Check if partition already exists (e.g., created on startup)
            Boolean partitionExists = jdbcTemplate.queryForObject(
                "SELECT EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = ?)",
                Boolean.class,
                partitionName
            );
            
            if (Boolean.TRUE.equals(partitionExists)) {
                log.info("Partition {} already exists (likely created on startup). Skipping creation.", partitionName);
                return;
            }
            
            String sql = String.format(
                "CREATE TABLE IF NOT EXISTS %s PARTITION OF url_mappings " +
                "FOR VALUES FROM ('%s') TO ('%s')",
                partitionName,
                startDate,
                endDate
            );
            
            jdbcTemplate.execute(sql);
            log.info("Successfully created partition: {} (from {} to {})", 
                    partitionName, startDate, endDate);
                    
        } catch (Exception e) {
            log.error("Error creating next month's partition", e);
        }
    }
    
    /**
     * Creates partitions for the next N months
     * Useful for initial setup or manual partition creation
     * 
     * @param months Number of months to create partitions for
     */
    public void createPartitionsForNextMonths(int months) {
        log.info("Creating partitions for next {} months...", months);
        
        for (int i = 1; i <= months; i++) {
            try {
                LocalDate targetMonth = LocalDate.now().plusMonths(i);
                LocalDate startDate = targetMonth.withDayOfMonth(1);
                LocalDate endDate = startDate.plusMonths(1);
                String partitionName = "url_mappings_" + startDate.format(PARTITION_DATE_FORMAT);
                
                String sql = String.format(
                    "CREATE TABLE IF NOT EXISTS %s PARTITION OF url_mappings " +
                    "FOR VALUES FROM ('%s') TO ('%s')",
                    partitionName,
                    startDate,
                    endDate
                );
                
                jdbcTemplate.execute(sql);
                log.info("Created partition: {} (from {} to {})", 
                        partitionName, startDate, endDate);
                        
            } catch (Exception e) {
                log.error("Error creating partition for month {}", i, e);
            }
        }
    }
    
    /**
     * Manually create next month's partition
     * Can be called via REST endpoint or scheduled task
     */
    public void createNextMonthPartitionManually() {
        createNextMonthPartition();
    }
    
    /**
     * Gets partition statistics
     * Returns information about all partitions including row counts and sizes
     * 
     * @return partition statistics as formatted string
     */
    public String getPartitionStatistics() {
        try {
            String sql = 
                "SELECT " +
                "    tablename AS partition_name, " +
                "    pg_size_pretty(pg_total_relation_size(quote_ident(tablename)::regclass)) AS size " +
                "FROM pg_tables " +
                "WHERE schemaname = 'public' " +
                "AND tablename LIKE 'url_mappings_%' " +
                "AND tablename ~ '^url_mappings_\\d{4}_\\d{2}$' " +
                "ORDER BY tablename";
            
            return jdbcTemplate.query(sql, (rs, rowNum) -> 
                String.format("%s: %s", rs.getString("partition_name"), rs.getString("size"))
            ).toString();
            
        } catch (Exception e) {
            log.error("Error getting partition statistics", e);
            return "Error retrieving partition statistics: " + e.getMessage();
        }
    }
}

