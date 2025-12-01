package com.shortify.gateway;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * API Gateway Application
 * 
 * Main entry point for the API Gateway service.
 * Routes requests to appropriate microservices:
 * - Create Service (port 8081): URL creation operations
 * - Lookup Service (port 8082): URL lookup and redirect operations
 * 
 * Features:
 * - Request routing and load balancing
 * - Rate limiting
 * - CORS configuration
 * - Request/response logging
 * - Health checks
 */
@SpringBootApplication
public class ApiGatewayApplication {
    
    public static void main(String[] args) {
        SpringApplication.run(ApiGatewayApplication.class, args);
    }
}

