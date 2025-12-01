package com.shortify.lookup;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.autoconfigure.domain.EntityScan;
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;
import org.springframework.scheduling.annotation.EnableScheduling;

/**
 * Lookup Service Application
 * Microservice dedicated to URL lookup and redirect operations
 * 
 * Scans common module for entities and repositories
 */
@SpringBootApplication(scanBasePackages = {"com.shortify.lookup", "com.shortify"})
@EntityScan(basePackages = "com.shortify.entity")
@EnableJpaRepositories(basePackages = "com.shortify.lookup.repository")
@EnableScheduling  // For cleanup jobs if needed
public class LookupServiceApplication {
    public static void main(String[] args) {
        SpringApplication.run(LookupServiceApplication.class, args);
    }
}

