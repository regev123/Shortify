package com.shortify.create.service;

import com.shortify.create.util.Base62Encoder;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Test to demonstrate how the mapping works and why it stays at 6 characters
 */
@DisplayName("UrlCodeGenerator Mapping Explanation")
class UrlCodeGeneratorMappingTest {

    @Test
    @DisplayName("Demonstrate how mapping keeps codes at 6 characters")
    void demonstrateMappingLogic() {
        // Constants from UrlCodeGenerator
        long MIN_6_CHAR = 916_132_832L; // 62^5 (first 6-character value)
        long MAX_6_CHAR = 56_800_235_583L; // 62^6 - 1 (last 6-character value)
        long RANGE_SIZE = MAX_6_CHAR - MIN_6_CHAR + 1; // 55,884,102,752
        
        System.out.println("=== Mapping Logic Explanation ===\n");
        System.out.println("Constants:");
        System.out.println("  MIN_6_CHAR: " + MIN_6_CHAR + " → Base62: \"" + Base62Encoder.encode(MIN_6_CHAR) + "\" (" + Base62Encoder.encode(MIN_6_CHAR).length() + " chars)");
        System.out.println("  MAX_6_CHAR: " + MAX_6_CHAR + " → Base62: \"" + Base62Encoder.encode(MAX_6_CHAR) + "\" (" + Base62Encoder.encode(MAX_6_CHAR).length() + " chars)");
        System.out.println("  RANGE_SIZE: " + RANGE_SIZE + "\n");
        
        // Simulate different Snowflake IDs
        long[] snowflakeIds = {
            11_235_840_000_135_168L,      // Small Snowflake ID
            11_235_840_000_135_169L,      // Next ID
            50_000_000_000_000_000L,      // Large Snowflake ID
            100_000_000_000_000_000L,     // Very large Snowflake ID
            Long.MAX_VALUE                // Maximum possible Snowflake ID
        };
        
        System.out.println("=== Mapping Examples ===\n");
        for (long snowflakeId : snowflakeIds) {
            // This is what happens in UrlCodeGenerator line 61
            long mappedId = MIN_6_CHAR + (Math.abs(snowflakeId) % RANGE_SIZE);
            String code = Base62Encoder.encode(mappedId);
            
            System.out.println("Snowflake ID: " + String.format("%,d", snowflakeId));
            System.out.println("  Modulo: " + (Math.abs(snowflakeId) % RANGE_SIZE));
            System.out.println("  Mapped ID: " + String.format("%,d", mappedId));
            System.out.println("  Base62 Code: \"" + code + "\" (" + code.length() + " chars)");
            System.out.println("  Range: " + MIN_6_CHAR + " ≤ " + mappedId + " ≤ " + MAX_6_CHAR);
            System.out.println();
            
            // Verify it's always in 6-char range
            assertThat(mappedId).isBetween(MIN_6_CHAR, MAX_6_CHAR);
            assertThat(code.length()).isEqualTo(6);
        }
        
        System.out.println("=== Key Insight ===");
        System.out.println("The modulo operation ensures:");
        System.out.println("  mappedId = MIN_6_CHAR + (SnowflakeID % RANGE_SIZE)");
        System.out.println("  This ALWAYS produces: MIN_6_CHAR ≤ mappedId ≤ MAX_6_CHAR");
        System.out.println("  Therefore: Codes will ALWAYS be 6 characters");
        System.out.println("  They will NEVER automatically grow to 7 characters!");
        System.out.println("\nTo grow to 7 characters, we need a different approach.");
    }
}

