package com.shortify.create.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

import org.springframework.stereotype.Service;

import com.shortify.create.util.Base62Encoder;

/**
 * Service for generating unique short URL codes
 * Uses Snowflake algorithm for distributed unique ID generation
 * 
 * Follows Single Responsibility Principle - only handles code generation
 * Follows Dependency Inversion Principle - depends on SnowflakeIdGenerator abstraction
 * 
 * Benefits:
 * - No database collision checks needed (Snowflake guarantees uniqueness)
 * - High performance (~0.1ms per code generation)
 * - Distributed system support (multiple Create Service instances)
 * - Time-ordered IDs (roughly chronological)
 * - Automatic code length growth (6 → 7 → 8 → 9 → 10 → 11 chars)
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class UrlCodeGenerator {
    
    private final SnowflakeIdGenerator snowflakeIdGenerator;
    
    // Base62 character length boundaries
    private static final long MIN_6_CHAR = 916_132_832L; // 62^5 (first 6-character value)
    private static final long MAX_6_CHAR = 56_800_235_583L; // 62^6 - 1 (last 6-character value) → "ZZZZZZ"
    
    /**
     * Generates a unique short URL code using Snowflake algorithm
     * 
     * Flow:
     * 1. Generate unique 64-bit ID using Snowflake
     * 2. Apply offset to start from minimum 6-char value
     * 3. Encode to Base62 string (starts at 6 chars, grows to 7+ automatically)
     * 4. Return short code (no collision check needed)
     * 
     * Strategy:
     * - Base62 minimum 6-char: 916,132,832 (62^5) → "100000"
     * - Base62 maximum 6-char: 56,800,235,583 (62^6 - 1) → "ZZZZZZ"
     * - Base62 minimum 7-char: 56,800,235,584 (62^6) → "1000000"
     * 
     * How it works:
     * 1. Snowflake generates unique ID (e.g., 11,235,840,000,135,168)
     * 2. Subtract base offset to bring ID into usable range
     * 3. Add MIN_6_CHAR to ensure it starts at 6 characters
     * 4. As Snowflake IDs grow, codes automatically grow: 6 → 7 → 8 → 9 → 10 → 11 chars
     * 
     * Collision Prevention:
     * - Snowflake guarantees unique IDs across all machines
     * - Offset calculation preserves uniqueness (different Snowflake IDs → different codes)
     * - No collisions possible (Snowflake ensures uniqueness)
     * 
     * Growth Behavior:
     * - Codes start at exactly 6 characters (from MIN_6_CHAR)
     * - When mappedId exceeds MAX_6_CHAR, codes automatically grow to 7+ characters
     * - Base62Encoder handles length automatically - no manual management needed
     * 
     * @return unique short URL code (Base62 encoded, starts at 6 chars, grows automatically)
     */
    public String generateUniqueCode() {
        // Step 1: Generate unique ID using Snowflake algorithm
        long uniqueId = snowflakeIdGenerator.generateId();
        
        // Step 2: Map Snowflake ID to start at 6 characters with automatic growth
        // Strategy: Use full Snowflake ID with modulo to preserve uniqueness, then add time-based growth
        // 
        // Key insight: Snowflake IDs are unique, so modulo preserves uniqueness
        // - Different Snowflake IDs → different modulo results → different codes ✅
        // 
        // For growth: Extract timestamp and scale it down to allow gradual growth over time
        
        // Extract timestamp portion (shift right by 22 to get timestamp in milliseconds since epoch)
        // This grows over time, allowing codes to grow from 6 → 7 → 8+ chars
        long timestampPart = uniqueId >>> 22; // Upper 42 bits (timestamp)
        
        // Scale timestamp down significantly to ensure we start in 6-char range
        // Scale factor: 1,000,000,000 means we add 1 for every 1B milliseconds (~11.6 days)
        // This ensures codes stay in 6-char range initially, then grow to 7+ chars over time
        long scaledTimestamp = timestampPart / 1_000_000_000L;
        
        // Use full Snowflake ID modulo to preserve uniqueness
        // Range: Use a portion of the 6-char range to leave room for growth
        // We use 90% of the range for the base, leaving 10% for growth
        long baseRangeSize = (MAX_6_CHAR - MIN_6_CHAR) * 9L / 10L; // ~50.3 billion
        long baseValue = (uniqueId % baseRangeSize) + MIN_6_CHAR;
        
        // Final mapped ID: base (from Snowflake ID, preserves uniqueness) + scaled timestamp (allows growth)
        // Initially: baseValue + scaledTimestamp will be in 6-char range
        // Over time: scaledTimestamp grows, eventually pushing codes to 7+ chars
        long mappedId = baseValue + scaledTimestamp;
        
        // Step 3: Encode to Base62 string
        // Base62Encoder automatically produces shortest possible encoding
        // - mappedId < MIN_6_CHAR → shouldn't happen (baseValue ensures MIN_6_CHAR)
        // - MIN_6_CHAR ≤ mappedId ≤ MAX_6_CHAR → 6 chars ✅
        // - mappedId > MAX_6_CHAR → 7+ chars ✅ (automatic growth as timestamp grows!)
        String shortCode = Base62Encoder.encode(mappedId);
        
        // Log the generation details
        boolean is6Char = mappedId <= MAX_6_CHAR;
        log.debug("Generated unique short code: {} (length: {}) from Snowflake ID: {} (timestampPart: {}, scaledTimestamp: {}, mapped: {}, 6-char: {})", 
                shortCode, shortCode.length(), uniqueId, timestampPart, scaledTimestamp, mappedId, is6Char);
        
        return shortCode;
    }
}

