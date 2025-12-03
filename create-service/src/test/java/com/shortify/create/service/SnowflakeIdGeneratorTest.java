package com.shortify.create.service;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.HashSet;
import java.util.Set;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicInteger;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@DisplayName("SnowflakeIdGenerator Tests")
class SnowflakeIdGeneratorTest {

    private SnowflakeIdGenerator generator;

    @BeforeEach
    void setUp() {
        generator = new SnowflakeIdGenerator(1L, 1L);
    }

    @Test
    @DisplayName("generateId - Generates unique IDs")
    void generateId_GeneratesUniqueIds() {
        // Given & When
        long id1 = generator.generateId();
        long id2 = generator.generateId();

        // Then
        assertThat(id1).isNotEqualTo(id2);
        assertThat(id1).isPositive();
        assertThat(id2).isPositive();
    }

    @Test
    @DisplayName("generateId - Generates positive IDs")
    void generateId_GeneratesPositiveIds() {
        // When
        long id = generator.generateId();

        // Then
        assertThat(id).isPositive();
    }

    @Test
    @DisplayName("generateId - Generates time-ordered IDs")
    void generateId_GeneratesTimeOrderedIds() throws InterruptedException {
        // Given
        long id1 = generator.generateId();
        Thread.sleep(1); // Wait 1ms to ensure different timestamp
        long id2 = generator.generateId();

        // Then
        assertThat(id2).isGreaterThan(id1); // Later ID should be larger
    }

    @Test
    @DisplayName("generateId - Handles rapid generation (sequence increment)")
    void generateId_RapidGeneration_IncrementsSequence() {
        // Given
        Set<Long> ids = new HashSet<>();
        int count = 100;

        // When
        for (int i = 0; i < count; i++) {
            ids.add(generator.generateId());
        }

        // Then
        assertThat(ids).hasSize(count); // All IDs should be unique
    }

    @Test
    @DisplayName("generateId - Thread-safe concurrent generation")
    void generateId_ConcurrentGeneration_AllUnique() throws InterruptedException {
        // Given
        int threadCount = 10;
        int idsPerThread = 100;
        ExecutorService executor = Executors.newFixedThreadPool(threadCount);
        CountDownLatch latch = new CountDownLatch(threadCount);
        Set<Long> allIds = new HashSet<>();
        AtomicInteger duplicateCount = new AtomicInteger(0);

        // When
        for (int i = 0; i < threadCount; i++) {
            executor.submit(() -> {
                try {
                    for (int j = 0; j < idsPerThread; j++) {
                        long id = generator.generateId();
                        synchronized (allIds) {
                            if (!allIds.add(id)) {
                                duplicateCount.incrementAndGet();
                            }
                        }
                    }
                } finally {
                    latch.countDown();
                }
            });
        }

        latch.await();
        executor.shutdown();

        // Then
        int expectedCount = threadCount * idsPerThread;
        assertThat(allIds).hasSize(expectedCount); // All IDs should be unique
        assertThat(duplicateCount.get()).isZero(); // No duplicates
    }

    @Test
    @DisplayName("Constructor - Validates worker ID range")
    void constructor_InvalidWorkerId_ThrowsException() {
        // When & Then
        assertThatThrownBy(() -> new SnowflakeIdGenerator(-1L, 1L))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("Worker ID must be between 0 and 31");

        assertThatThrownBy(() -> new SnowflakeIdGenerator(32L, 1L))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("Worker ID must be between 0 and 31");
    }

    @Test
    @DisplayName("Constructor - Validates datacenter ID range")
    void constructor_InvalidDatacenterId_ThrowsException() {
        // When & Then
        assertThatThrownBy(() -> new SnowflakeIdGenerator(1L, -1L))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("Datacenter ID must be between 0 and 31");

        assertThatThrownBy(() -> new SnowflakeIdGenerator(1L, 32L))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("Datacenter ID must be between 0 and 31");
    }

    @Test
    @DisplayName("Constructor - Accepts valid IDs")
    void constructor_ValidIds_CreatesInstance() {
        // When & Then - should not throw
        SnowflakeIdGenerator gen1 = new SnowflakeIdGenerator(0L, 0L);
        SnowflakeIdGenerator gen2 = new SnowflakeIdGenerator(31L, 31L);
        SnowflakeIdGenerator gen3 = new SnowflakeIdGenerator(15L, 20L);

        assertThat(gen1).isNotNull();
        assertThat(gen2).isNotNull();
        assertThat(gen3).isNotNull();
    }

    @Test
    @DisplayName("getWorkerId - Returns configured worker ID")
    void getWorkerId_ReturnsConfiguredWorkerId() {
        // Given
        long expectedWorkerId = 5L;
        SnowflakeIdGenerator gen = new SnowflakeIdGenerator(expectedWorkerId, 1L);

        // When
        long workerId = gen.getWorkerId();

        // Then
        assertThat(workerId).isEqualTo(expectedWorkerId);
    }

    @Test
    @DisplayName("getDatacenterId - Returns configured datacenter ID")
    void getDatacenterId_ReturnsConfiguredDatacenterId() {
        // Given
        long expectedDatacenterId = 10L;
        SnowflakeIdGenerator gen = new SnowflakeIdGenerator(1L, expectedDatacenterId);

        // When
        long datacenterId = gen.getDatacenterId();

        // Then
        assertThat(datacenterId).isEqualTo(expectedDatacenterId);
    }

    @Test
    @DisplayName("generateId - Different workers generate different IDs")
    void generateId_DifferentWorkers_GenerateDifferentIds() {
        // Given
        SnowflakeIdGenerator gen1 = new SnowflakeIdGenerator(1L, 1L);
        SnowflakeIdGenerator gen2 = new SnowflakeIdGenerator(2L, 1L);

        // When
        long id1 = gen1.generateId();
        long id2 = gen2.generateId();

        // Then
        assertThat(id1).isNotEqualTo(id2);
    }

    @Test
    @DisplayName("generateId - Different datacenters generate different IDs")
    void generateId_DifferentDatacenters_GenerateDifferentIds() {
        // Given
        SnowflakeIdGenerator gen1 = new SnowflakeIdGenerator(1L, 1L);
        SnowflakeIdGenerator gen2 = new SnowflakeIdGenerator(1L, 2L);

        // When
        long id1 = gen1.generateId();
        long id2 = gen2.generateId();

        // Then
        assertThat(id1).isNotEqualTo(id2);
    }
}

