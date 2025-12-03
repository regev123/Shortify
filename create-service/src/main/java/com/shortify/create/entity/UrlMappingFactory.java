package com.shortify.create.entity;

import com.shortify.entity.UrlMapping;
import lombok.AccessLevel;
import lombok.NoArgsConstructor;

import static com.shortify.create.constants.CreateUrlConstants.DEFAULT_EXPIRATION_YEARS;

import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * Factory for creating UrlMapping entities
 * Part of the Create Service microservice
 * 
 * Follows Factory Pattern - encapsulates object creation logic
 * Follows Single Responsibility Principle - only handles entity creation
 * Follows Encapsulation - prevents direct instantiation
 */
@NoArgsConstructor(access = AccessLevel.PRIVATE)
public final class UrlMappingFactory {
    
    private static final long DEFAULT_ACCESS_COUNT = 0L;
    
    /**
     * Creates a new UrlMapping entity with default values
     * Uses factory pattern to ensure consistent entity creation
     * 
     * @param originalUrl the original URL to shorten (must not be null)
     * @param shortCode the generated short code (must not be null)
     * @return new UrlMapping entity with default values set
     * @throws IllegalArgumentException if originalUrl or shortCode is null
     */
    public static UrlMapping create(String originalUrl, String shortCode) {
        if (originalUrl == null || originalUrl.trim().isEmpty()) {
            throw new IllegalArgumentException("Original URL cannot be null or empty");
        }
        if (shortCode == null || shortCode.trim().isEmpty()) {
            throw new IllegalArgumentException("Short code cannot be null or empty");
        }
        
        LocalDateTime now = LocalDateTime.now();
        LocalDate today = LocalDate.now();
        
        UrlMapping mapping = new UrlMapping();
        mapping.setOriginalUrl(originalUrl);
        mapping.setShortUrl(shortCode);
        mapping.setCreatedAt(now);
        mapping.setCreatedDate(today);  // Set partition key explicitly
        mapping.setExpiresAt(now.plusYears(DEFAULT_EXPIRATION_YEARS));
        mapping.setAccessCount(DEFAULT_ACCESS_COUNT);
        mapping.setLastAccessedAt(null); // Will be set on first access
        mapping.setShardId(0);  // Default shard ID (single shard for now)
        
        return mapping;
    }
}

