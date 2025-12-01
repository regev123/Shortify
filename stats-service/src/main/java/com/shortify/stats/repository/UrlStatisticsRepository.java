package com.shortify.stats.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import com.shortify.stats.entity.UrlStatistics;

import java.util.Optional;

@Repository
public interface UrlStatisticsRepository extends JpaRepository<UrlStatistics, Long> {
    
    Optional<UrlStatistics> findByShortCode(String shortCode);
    
    /**
     * Delete statistics for a specific shortCode.
     * Used when cleaning up orphaned statistics.
     */
    @Modifying
    @Transactional
    @Query("DELETE FROM UrlStatistics s WHERE s.shortCode = :shortCode")
    void deleteByShortCode(@Param("shortCode") String shortCode);
}

