package com.shortify.event;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.io.Serializable;

/**
 * Event published when a URL is deleted from the main database.
 * Consumed by Stats Service to clean up orphaned statistics.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UrlDeletedEvent implements Serializable {
    private String shortCode;
    private String reason; // "EXPIRED", "UNUSED", "MANUAL_DELETE"
    private Long timestamp; // Unix timestamp in milliseconds
}

