package com.shortify.create.util;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Test to demonstrate automatic code length progression
 * Shows how Base62Encoder automatically handles different ID sizes
 */
@DisplayName("Base62Encoder Length Progression Tests")
class Base62EncoderLengthTest {

    @Test
    @DisplayName("Demonstrate automatic length progression from 6 to 11 characters")
    void demonstrateAutomaticLengthProgression() {
        // Small IDs (4-6 characters)
        assertThat(Base62Encoder.encode(1L)).hasSizeLessThanOrEqualTo(6);
        assertThat(Base62Encoder.encode(1_000_000L)).hasSizeLessThanOrEqualTo(6);
        assertThat(Base62Encoder.encode(1_000_000_000L)).hasSizeLessThanOrEqualTo(6);
        
        // Maximum 6-character Base62 value
        long max6Char = 56_800_235_583L; // 62^6 - 1
        String max6CharCode = Base62Encoder.encode(max6Char);
        assertThat(max6CharCode).hasSize(6);
        System.out.println("Max 6-char ID: " + max6Char + " → Code: \"" + max6CharCode + "\" (" + max6CharCode.length() + " chars)");
        
        // First 7-character value (automatic progression)
        long first7Char = 56_800_235_584L; // 62^6
        String first7CharCode = Base62Encoder.encode(first7Char);
        assertThat(first7CharCode).hasSize(7);
        System.out.println("First 7-char ID: " + first7Char + " → Code: \"" + first7CharCode + "\" (" + first7CharCode.length() + " chars)");
        
        // Maximum 7-character Base62 value
        long max7Char = 3_521_614_606_207L; // 62^7 - 1
        String max7CharCode = Base62Encoder.encode(max7Char);
        assertThat(max7CharCode).hasSize(7);
        System.out.println("Max 7-char ID: " + max7Char + " → Code: \"" + max7CharCode + "\" (" + max7CharCode.length() + " chars)");
        
        // First 8-character value (automatic progression)
        long first8Char = 3_521_614_606_208L; // 62^7
        String first8CharCode = Base62Encoder.encode(first8Char);
        assertThat(first8CharCode).hasSize(8);
        System.out.println("First 8-char ID: " + first8Char + " → Code: \"" + first8CharCode + "\" (" + first8CharCode.length() + " chars)");
        
        // Very large IDs (9-11 characters)
        long largeId = 100_000_000_000_000L;
        String largeCode = Base62Encoder.encode(largeId);
        assertThat(largeCode.length()).isGreaterThan(7);
        System.out.println("Large ID: " + largeId + " → Code: \"" + largeCode + "\" (" + largeCode.length() + " chars)");
        
        // Maximum 64-bit value (Snowflake max)
        long max64Bit = 9_223_372_036_854_775_807L; // Long.MAX_VALUE
        String maxCode = Base62Encoder.encode(max64Bit);
        assertThat(maxCode.length()).isLessThanOrEqualTo(11);
        System.out.println("Max 64-bit ID: " + max64Bit + " → Code: \"" + maxCode + "\" (" + maxCode.length() + " chars)");
    }

    @Test
    @DisplayName("Show progression at key thresholds")
    void showProgressionAtKeyThresholds() {
        System.out.println("\n=== Base62 Code Length Progression ===");
        
        // 6-character range
        System.out.println("\n6-character codes (0 to 56,800,235,583):");
        System.out.println("  ID: 1,000,000 → Code: \"" + Base62Encoder.encode(1_000_000L) + "\"");
        System.out.println("  ID: 56,800,235,583 → Code: \"" + Base62Encoder.encode(56_800_235_583L) + "\" (MAX 6-char)");
        
        // 7-character range
        System.out.println("\n7-character codes (56,800,235,584 to 3,521,614,606,207):");
        System.out.println("  ID: 56,800,235,584 → Code: \"" + Base62Encoder.encode(56_800_235_584L) + "\" (FIRST 7-char)");
        System.out.println("  ID: 3,521,614,606,207 → Code: \"" + Base62Encoder.encode(3_521_614_606_207L) + "\" (MAX 7-char)");
        
        // 8-character range
        System.out.println("\n8-character codes (3,521,614,606,208 to 218,340,105,584,895):");
        System.out.println("  ID: 3,521,614,606,208 → Code: \"" + Base62Encoder.encode(3_521_614_606_208L) + "\" (FIRST 8-char)");
        
        // 11-character (max for 64-bit)
        System.out.println("\n11-character codes (max for 64-bit long):");
        System.out.println("  ID: 9,223,372,036,854,775,807 → Code: \"" + Base62Encoder.encode(Long.MAX_VALUE) + "\"");
        
        System.out.println("\n✅ Progression is AUTOMATIC - no configuration needed!");
    }
}

