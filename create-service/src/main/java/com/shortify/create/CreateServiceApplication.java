package com.shortify.create;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.autoconfigure.domain.EntityScan;
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;

/**
 * Create Service Application
 * Microservice dedicated to URL creation operations
 * 
 * Scans common module for entities and repositories
 */
@SpringBootApplication(scanBasePackages = {"com.shortify.create", "com.shortify"})
@EntityScan(basePackages = "com.shortify.entity")
@EnableJpaRepositories(basePackages = "com.shortify.create.repository")
public class CreateServiceApplication {
    public static void main(String[] args) {
        SpringApplication.run(CreateServiceApplication.class, args);
    }
}

