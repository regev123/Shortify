package com.shortify.create.util;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Test to verify long data type capacity for Base62 encoding
 * Demonstrates that long (64-bit) can handle all Base62 encoding needs
 */
@DisplayName("Base62Encoder Capacity Tests - Long Data Type Limits")
class Base62EncoderCapacityTest {

    @Test
    @DisplayName("Verify long data type limits")
    void verifyLongDataTypeLimits() {
        // Java long is 64-bit signed integer
        long minLong = Long.MIN_VALUE; // -9,223,372,036,854,775,808
        long maxLong = Long.MAX_VALUE; // 9,223,372,036,854,775,807
        
        System.out.println("=== Long Data Type Limits ===");
        System.out.println("Min long: " + minLong);
        System.out.println("Max long: " + maxLong);
        System.out.println("Max long (scientific): " + String.format("%.2e", (double) maxLong));
        
        // Base62Encoder only works with non-negative numbers
        assertThat(maxLong).isPositive();
        assertThat(maxLong).isEqualTo(9_223_372_036_854_775_807L);
    }

    @Test
    @DisplayName("Verify Base62 encoding of maximum long value")
    void verifyBase62EncodingOfMaxLong() {
        long maxLong = Long.MAX_VALUE; // 9,223,372,036,854,775,807
        
        String encoded = Base62Encoder.encode(maxLong);
        
        System.out.println("\n=== Base62 Encoding of Max Long ===");
        System.out.println("Max long value: " + maxLong);
        System.out.println("Base62 encoded: \"" + encoded + "\"");
        System.out.println("Length: " + encoded.length() + " characters");
        
        // Maximum Base62 encoding of 64-bit number is 11 characters
        assertThat(encoded.length()).isLessThanOrEqualTo(11);
        assertThat(encoded.length()).isGreaterThanOrEqualTo(1);
    }

    @Test
    @DisplayName("Show Base62 capacity at different long values")
    void showBase62CapacityAtDifferentLongValues() {
        System.out.println("\n=== Base62 Capacity at Different Long Values ===");
        
        // Small values
        long small = 1_000_000L;
        System.out.println("ID: " + small + " → Code: \"" + Base62Encoder.encode(small) + "\" (" + Base62Encoder.encode(small).length() + " chars)");
        
        // Medium values (6-char max)
        long medium = 56_800_235_583L; // Max 6-char
        System.out.println("ID: " + medium + " → Code: \"" + Base62Encoder.encode(medium) + "\" (" + Base62Encoder.encode(medium).length() + " chars)");
        
        // Large values (7-char)
        long large = 3_521_614_606_207L; // Max 7-char
        System.out.println("ID: " + large + " → Code: \"" + Base62Encoder.encode(large) + "\" (" + Base62Encoder.encode(large).length() + " chars)");
        
        // Very large values (8-char)
        long veryLarge = 218_340_105_584_895L; // Max 8-char
        System.out.println("ID: " + veryLarge + " → Code: \"" + Base62Encoder.encode(veryLarge) + "\" (" + Base62Encoder.encode(veryLarge).length() + " chars)");
        
        // Maximum long value (11-char)
        long maxLong = Long.MAX_VALUE;
        System.out.println("ID: " + maxLong + " → Code: \"" + Base62Encoder.encode(maxLong) + "\" (" + Base62Encoder.encode(maxLong).length() + " chars)");
    }

    @Test
    @DisplayName("Calculate how many URLs long can support")
    void calculateHowManyUrlsLongCanSupport() {
        long maxLong = Long.MAX_VALUE; // 9,223,372,036,854,775,807
        
        System.out.println("\n=== Long Capacity Analysis ===");
        System.out.println("Maximum long value: " + maxLong);
        System.out.println("That's: " + String.format("%.2e", (double) maxLong) + " unique IDs");
        
        // Calculate years at different rates
        long idsPerSecond = 1_000_000L; // 1 million IDs per second
        long idsPerDay = idsPerSecond * 60 * 60 * 24; // IDs per day
        long idsPerYear = idsPerDay * 365; // IDs per year
        
        long yearsAt1MPerSec = maxLong / idsPerYear;
        System.out.println("\nAt 1 million IDs/second:");
        System.out.println("  IDs per day: " + idsPerDay);
        System.out.println("  IDs per year: " + idsPerYear);
        System.out.println("  Years until max: " + yearsAt1MPerSec);
        
        // Snowflake capacity
        long snowflakeMaxPerSecond = 4_200_000_000L; // 4.2B IDs/sec (theoretical max)
        long snowflakeIdsPerYear = snowflakeMaxPerSecond * 60 * 60 * 24 * 365;
        long yearsAtSnowflakeMax = maxLong / snowflakeIdsPerYear;
        System.out.println("\nAt Snowflake max (4.2B IDs/second):");
        System.out.println("  IDs per year: " + snowflakeIdsPerYear);
        System.out.println("  Years until max: " + yearsAtSnowflakeMax);
        
        // Realistic scenario (100M URLs/day)
        long realisticIdsPerDay = 100_000_000L;
        long realisticIdsPerYear = realisticIdsPerDay * 365;
        long yearsAtRealistic = maxLong / realisticIdsPerYear;
        System.out.println("\nAt realistic rate (100M URLs/day):");
        System.out.println("  IDs per year: " + realisticIdsPerYear);
        System.out.println("  Years until max: " + yearsAtRealistic);
    }

    @Test
    @DisplayName("Verify Snowflake ID fits in long")
    void verifySnowflakeIdFitsInLong() {
        // Snowflake generates 64-bit IDs
        // Long is 64-bit, so it can hold any Snowflake ID
        
        System.out.println("\n=== Snowflake ID Compatibility ===");
        System.out.println("Snowflake ID: 64-bit integer");
        System.out.println("Java long: 64-bit signed integer");
        System.out.println("✅ Snowflake IDs fit perfectly in long!");
        
        // Test with realistic Snowflake ID values
        long snowflakeId1 = 1_234_567_890_123_456_789L;
        long snowflakeId2 = 9_223_372_036_854_775_807L; // Max long
        
        String code1 = Base62Encoder.encode(snowflakeId1);
        String code2 = Base62Encoder.encode(snowflakeId2);
        
        System.out.println("\nSnowflake ID examples:");
        System.out.println("  ID: " + snowflakeId1 + " → Code: \"" + code1 + "\"");
        System.out.println("  ID: " + snowflakeId2 + " → Code: \"" + code2 + "\"");
        
        assertThat(code1.length()).isLessThanOrEqualTo(11);
        assertThat(code2.length()).isLessThanOrEqualTo(11);
    }
}

