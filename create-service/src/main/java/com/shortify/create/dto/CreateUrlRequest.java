package com.shortify.create.dto;

import static com.shortify.create.constants.CreateUrlConstants.MAX_ORIGINAL_URL_LENGTH;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Request DTO for creating a short URL
 * Part of the Create Service microservice
 * 
 * Follows Single Responsibility Principle - only holds request data
 * Follows Encapsulation - data is properly encapsulated with validation
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CreateUrlRequest {
    
    @NotBlank(message = "Original URL is required")
    @Size(max = MAX_ORIGINAL_URL_LENGTH, message = "Original URL exceeds maximum length")
    private String originalUrl;
    
    private String baseUrl;
}

