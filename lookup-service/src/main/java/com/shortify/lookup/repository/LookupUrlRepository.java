package com.shortify.lookup.repository;

import com.shortify.entity.UrlMapping;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

/**
 * Repository interface for URL lookup operations
 * Part of the Lookup Service microservice
 * 
 * Follows Interface Segregation Principle - only exposes methods needed for lookup
 * Follows Repository Pattern - abstracts data access layer
 * 
 * Spring Data JPA automatically implements these methods based on naming conventions
 */
@Repository
public interface LookupUrlRepository extends JpaRepository<UrlMapping, Long> {
    
    /**
     * Finds a URL mapping by short URL code
     * Used for URL lookup and redirect operations
     * 
     * @param shortUrl the short URL code
     * @return Optional containing the mapping if found
     */
    Optional<UrlMapping> findByShortUrl(String shortUrl);
    
    /**
     * Deletes URLs that haven't been accessed since the cutoff date OR have expired
     * Uses native query with CTE (Common Table Expression) for efficient batch deletion
     * 
     * Deletes URLs that match ANY of these conditions:
     * 1. lastAccessedAt < accessCutoffDate (or NULL and created_at < accessCutoffDate)
     * 2. expiresAt < currentTime (expired URLs)
     * 
     * @param accessCutoffDate URLs with lastAccessedAt before this date will be deleted
     * @param currentTime Current time to check expiration
     * @param batchSize maximum number of URLs to delete in this batch
     * @return number of URLs deleted
     */
    /**
     * Finds URLs that will be deleted (to get their shortCodes before deletion).
     * Used to publish deletion events to Kafka.
     * 
     * Optimized with partition pruning:
     * - For unused URLs: Only checks partitions where created_date < partitionCutoffDate (6+ months old)
     * - For expired URLs: Checks all partitions (expired URLs can be in any partition)
     * 
     * This dramatically reduces the number of partitions scanned, improving performance.
     */
    @Query(value = "SELECT * FROM url_mappings " +
                   "WHERE (" +
                   "  (created_date < :partitionCutoffDate AND " +
                   "   (last_accessed_at < :accessCutoffDate OR (last_accessed_at IS NULL AND created_at < :accessCutoffDate))) " +
                   "  OR " +
                   "  expires_at < :currentTime" +
                   ") " +
                   "LIMIT :batchSize",
           nativeQuery = true)
    List<UrlMapping> findUnusedOrExpiredUrls(
            @Param("accessCutoffDate") LocalDateTime accessCutoffDate,
            @Param("currentTime") LocalDateTime currentTime,
            @Param("partitionCutoffDate") java.time.LocalDate partitionCutoffDate,
            @Param("batchSize") int batchSize);
    
    /**
     * Deletes URLs that haven't been accessed since the cutoff date OR have expired.
     * Uses native query with CTE (Common Table Expression) for efficient batch deletion.
     * 
     * Optimized with partition pruning:
     * - For unused URLs: Only checks partitions where created_date < partitionCutoffDate (6+ months old)
     * - For expired URLs: Checks all partitions (expired URLs can be in any partition)
     * 
     * Deletes URLs that match ANY of these conditions:
     * 1. created_date < partitionCutoffDate AND (last_accessed_at < accessCutoffDate OR (last_accessed_at IS NULL AND created_at < accessCutoffDate))
     * 2. expires_at < currentTime (expired URLs)
     * 
     * @param accessCutoffDate URLs with lastAccessedAt before this date will be deleted
     * @param currentTime Current time to check expiration
     * @param partitionCutoffDate Only check partitions older than this date (for unused URLs)
     * @param batchSize maximum number of URLs to delete in this batch
     * @return number of URLs deleted
     */
    @Modifying
    @Query(value = "WITH ids_to_delete AS (" +
                   "  SELECT id FROM url_mappings " +
                   "  WHERE (" +
                   "    (created_date < :partitionCutoffDate AND " +
                   "     (last_accessed_at < :accessCutoffDate OR (last_accessed_at IS NULL AND created_at < :accessCutoffDate))) " +
                   "    OR " +
                   "    expires_at < :currentTime" +
                   "  ) " +
                   "  LIMIT :batchSize" +
                   ") " +
                   "DELETE FROM url_mappings WHERE id IN (SELECT id FROM ids_to_delete)", 
           nativeQuery = true)
    int deleteUnusedOrExpiredUrls(
            @Param("accessCutoffDate") LocalDateTime accessCutoffDate,
            @Param("currentTime") LocalDateTime currentTime,
            @Param("partitionCutoffDate") java.time.LocalDate partitionCutoffDate,
            @Param("batchSize") int batchSize);
}

