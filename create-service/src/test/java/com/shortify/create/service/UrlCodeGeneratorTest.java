package com.shortify.create.service;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import com.shortify.create.service.UrlCodeGenerator;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@DisplayName("UrlCodeGenerator Tests")
class UrlCodeGeneratorTest {

    @Mock
    private SnowflakeIdGenerator snowflakeIdGenerator;

    @InjectMocks
    private UrlCodeGenerator urlCodeGenerator;

    @BeforeEach
    void setUp() {
        // Reset any state if needed
    }

    @Test
    @DisplayName("generateUniqueCode - Successfully generates code from Snowflake ID")
    void generateUniqueCode_SnowflakeId_ReturnsBase62EncodedCode() {
        // Given
        long snowflakeId = 1234567890123456789L;
        when(snowflakeIdGenerator.generateId()).thenReturn(snowflakeId);

        // When
        String result = urlCodeGenerator.generateUniqueCode();

        // Then
        assertThat(result).isNotNull();
        assertThat(result).isNotEmpty();
        verify(snowflakeIdGenerator, times(1)).generateId();
    }

    @Test
    @DisplayName("generateUniqueCode - Generated code is alphanumeric (Base62)")
    void generateUniqueCode_GeneratedCode_IsAlphanumeric() {
        // Given
        long snowflakeId = 1000000L;
        when(snowflakeIdGenerator.generateId()).thenReturn(snowflakeId);

        // When
        String result = urlCodeGenerator.generateUniqueCode();

        // Then
        assertThat(result).matches("^[a-zA-Z0-9]+$");
        verify(snowflakeIdGenerator, times(1)).generateId();
    }

    @Test
    @DisplayName("generateUniqueCode - Generated codes are different for different IDs")
    void generateUniqueCode_MultipleCalls_GeneratesDifferentCodes() {
        // Given
        long id1 = 1000000L;
        long id2 = 2000000L;
        when(snowflakeIdGenerator.generateId())
                .thenReturn(id1)
                .thenReturn(id2);

        // When
        String code1 = urlCodeGenerator.generateUniqueCode();
        String code2 = urlCodeGenerator.generateUniqueCode();

        // Then
        assertThat(code1).isNotNull().isNotEmpty();
        assertThat(code2).isNotNull().isNotEmpty();
        assertThat(code1).isNotEqualTo(code2); // Different IDs should produce different codes
        assertThat(code1).matches("^[a-zA-Z0-9]+$");
        assertThat(code2).matches("^[a-zA-Z0-9]+$");
        verify(snowflakeIdGenerator, times(2)).generateId();
    }

    @Test
    @DisplayName("generateUniqueCode - Generated code length is reasonable")
    void generateUniqueCode_GeneratedCode_HasReasonableLength() {
        // Given
        long snowflakeId = 56800235583L; // Max 6-character Base62 value
        when(snowflakeIdGenerator.generateId()).thenReturn(snowflakeId);

        // When
        String result = urlCodeGenerator.generateUniqueCode();

        // Then
        assertThat(result.length()).isGreaterThan(0);
        assertThat(result.length()).isLessThanOrEqualTo(11); // Max Base62 length for 64-bit long
        verify(snowflakeIdGenerator, times(1)).generateId();
    }

    @Test
    @DisplayName("generateUniqueCode - Handles small Snowflake IDs (short codes)")
    void generateUniqueCode_SmallId_GeneratesShortCode() {
        // Given
        long smallId = 1000L;
        when(snowflakeIdGenerator.generateId()).thenReturn(smallId);

        // When
        String result = urlCodeGenerator.generateUniqueCode();

        // Then
        assertThat(result).isNotNull();
        assertThat(result.length()).isLessThanOrEqualTo(6); // Small IDs produce shorter codes
        verify(snowflakeIdGenerator, times(1)).generateId();
    }

    @Test
    @DisplayName("generateUniqueCode - Handles large Snowflake IDs (longer codes)")
    void generateUniqueCode_LargeId_GeneratesLongerCode() {
        // Given
        long largeId = 9000000000000000000L; // Very large ID
        when(snowflakeIdGenerator.generateId()).thenReturn(largeId);

        // When
        String result = urlCodeGenerator.generateUniqueCode();

        // Then
        assertThat(result).isNotNull();
        assertThat(result.length()).isGreaterThan(6); // Large IDs produce longer codes
        assertThat(result.length()).isLessThanOrEqualTo(11); // Max Base62 length
        verify(snowflakeIdGenerator, times(1)).generateId();
    }

    @Test
    @DisplayName("generateUniqueCode - No database collision check needed")
    void generateUniqueCode_NoCollisionCheck_NoRepositoryCall() {
        // Given
        long snowflakeId = 123456789L;
        when(snowflakeIdGenerator.generateId()).thenReturn(snowflakeId);

        // When
        String result = urlCodeGenerator.generateUniqueCode();

        // Then
        assertThat(result).isNotNull();
        // Verify Snowflake is called, but no repository collision check
        verify(snowflakeIdGenerator, times(1)).generateId();
        // No repository mock needed - collision detection removed
    }

    @Test
    @DisplayName("generateUniqueCode - Handles zero ID correctly")
    void generateUniqueCode_ZeroId_GeneratesValidCode() {
        // Given
        long zeroId = 0L;
        when(snowflakeIdGenerator.generateId()).thenReturn(zeroId);

        // When
        String result = urlCodeGenerator.generateUniqueCode();

        // Then
        assertThat(result).isEqualTo("0"); // Base62 encode of 0 is "0"
        verify(snowflakeIdGenerator, times(1)).generateId();
    }
}
