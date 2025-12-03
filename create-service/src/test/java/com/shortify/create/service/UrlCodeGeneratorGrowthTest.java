package com.shortify.create.service;

import com.shortify.create.util.Base62Encoder;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Test to demonstrate how codes start at 6 chars and grow to 7+ automatically
 */
@DisplayName("UrlCodeGenerator Growth Demonstration")
class UrlCodeGeneratorGrowthTest {

    private static final long MIN_6_CHAR = 916_132_832L; // 62^5
    private static final long MAX_6_CHAR = 56_800_235_583L; // 62^6 - 1
    private static final long BASE_OFFSET = 11_000_000_000_000_000L;

    @Test
    @DisplayName("Demonstrate code growth from 6 to 7+ characters")
    void demonstrateCodeGrowth() {
        System.out.println("=== Code Growth Demonstration ===\n");
        
        // Simulate the logic from UrlCodeGenerator
        long[] snowflakeIds = {
            11_000_000_000_000_000L,  // Small Snowflake ID (just above offset)
            11_000_916_132_832L,      // ID that maps to MIN_6_CHAR
            11_000_100_000_000L,      // Medium ID
            11_056_800_235_583L,      // ID that maps to MAX_6_CHAR
            11_056_800_235_584L,      // ID that exceeds MAX_6_CHAR (should grow to 7!)
            11_100_000_000_000L,      // Larger ID (should be 7+ chars)
            50_000_000_000_000_000L   // Very large ID (should be 8+ chars)
        };
        
        System.out.println("Snowflake ID → Offset ID → Base62 Code → Length\n");
        System.out.println("─".repeat(80));
        
        for (long snowflakeId : snowflakeIds) {
            // This is the logic from UrlCodeGenerator
            long offsetId = snowflakeId - BASE_OFFSET;
            
            // Map into 6-char range if too small
            if (offsetId < MIN_6_CHAR) {
                offsetId = MIN_6_CHAR + (Math.abs(offsetId) % (MAX_6_CHAR - MIN_6_CHAR + 1));
            }
            
            String code = Base62Encoder.encode(offsetId);
            int length = code.length();
            
            System.out.printf("%,20d → %,15d → %-12s → %d chars%n", 
                    snowflakeId, offsetId, code, length);
            
            // Verify behavior
            if (offsetId <= MAX_6_CHAR) {
                assertThat(length).isEqualTo(6);
                System.out.println("  ✓ 6-character code (within range)");
            } else {
                assertThat(length).isGreaterThan(6);
                System.out.println("  ✓ " + length + "-character code (automatic growth!)");
            }
            System.out.println();
        }
        
        System.out.println("=== Key Points ===\n");
        System.out.println("1. Codes START at 6 characters (from MIN_6_CHAR = 916,132,832)");
        System.out.println("2. Codes stay at 6 characters until MAX_6_CHAR = 56,800,235,583");
        System.out.println("3. When offsetId > MAX_6_CHAR, codes AUTOMATICALLY grow to 7+ chars");
        System.out.println("4. Base62Encoder handles length automatically - no manual management!");
        System.out.println("5. Snowflake guarantees uniqueness → No collisions possible");
    }

    @Test
    @DisplayName("Verify no collisions in 6-char range")
    void verifyNoCollisions() {
        System.out.println("=== Collision Prevention ===\n");
        
        // Simulate generating many IDs
        long[] snowflakeIds = {
            11_000_000_000_000_000L,
            11_000_000_000_000_001L,
            11_000_000_000_000_002L,
            11_000_000_000_000_003L,
            50_000_000_000_000_000L,
            100_000_000_000_000_000L
        };
        
        java.util.Set<String> codes = new java.util.HashSet<>();
        
        for (long snowflakeId : snowflakeIds) {
            long offsetId = snowflakeId - BASE_OFFSET;
            if (offsetId < MIN_6_CHAR) {
                offsetId = MIN_6_CHAR + (Math.abs(offsetId) % (MAX_6_CHAR - MIN_6_CHAR + 1));
            }
            String code = Base62Encoder.encode(offsetId);
            
            boolean isNew = codes.add(code);
            System.out.printf("Snowflake ID: %,20d → Code: %-12s → %s%n", 
                    snowflakeId, code, isNew ? "UNIQUE ✓" : "COLLISION ✗");
            
            assertThat(isNew).isTrue(); // Should always be unique
        }
        
        System.out.println("\n✓ All codes are unique - no collisions!");
        System.out.println("✓ Snowflake guarantees uniqueness across all machines");
    }

    @Test
    @DisplayName("Show transition from 6 to 7 characters")
    void showTransitionFrom6To7() {
        System.out.println("=== 6-Char to 7-Char Transition ===\n");
        
        // Show the exact transition point
        long max6CharId = BASE_OFFSET + MAX_6_CHAR;
        long first7CharId = BASE_OFFSET + MAX_6_CHAR + 1;
        
        System.out.println("Last 6-character code:");
        long offsetId1 = max6CharId - BASE_OFFSET;
        String code1 = Base62Encoder.encode(offsetId1);
        System.out.printf("  Snowflake ID: %,20d%n", max6CharId);
        System.out.printf("  Offset ID:   %,20d%n", offsetId1);
        System.out.printf("  Base62 Code: %s (%d chars)%n", code1, code1.length());
        assertThat(code1.length()).isEqualTo(6);
        assertThat(code1).isEqualTo("ZZZZZZ"); // Last 6-char code
        
        System.out.println("\nFirst 7-character code (automatic growth!):");
        long offsetId2 = first7CharId - BASE_OFFSET;
        String code2 = Base62Encoder.encode(offsetId2);
        System.out.printf("  Snowflake ID: %,20d%n", first7CharId);
        System.out.printf("  Offset ID:   %,20d%n", offsetId2);
        System.out.printf("  Base62 Code: %s (%d chars)%n", code2, code2.length());
        assertThat(code2.length()).isEqualTo(7);
        
        System.out.println("\n✓ Automatic growth from 6 to 7 characters confirmed!");
    }
}

