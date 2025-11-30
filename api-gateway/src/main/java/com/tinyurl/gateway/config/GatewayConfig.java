package com.tinyurl.gateway.config;

import com.tinyurl.gateway.util.IpAddressExtractor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.cloud.gateway.filter.GlobalFilter;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.annotation.Order;
import org.springframework.http.server.reactive.ServerHttpRequest;
import org.springframework.http.server.reactive.ServerHttpResponse;
import reactor.core.publisher.Mono;

import java.time.Duration;
import java.time.Instant;

/**
 * Gateway Configuration
 * 
 * Global filters for request/response logging and monitoring.
 * This functionality is NOT available via YAML configuration.
 */
@Configuration
@Slf4j
public class GatewayConfig {
    
    /**
     * Global filter for logging requests and responses
     */
    @Bean
    @Order(-1)
    public GlobalFilter loggingFilter() {
        return (exchange, chain) -> {
            ServerHttpRequest request = exchange.getRequest();
            Instant startTime = Instant.now();
            
            String requestPath = request.getURI().getPath();
            String method = request.getMethod().toString();
            String clientIp = IpAddressExtractor.extractIp(request);
            
            log.info("Incoming request: {} {} from {}", method, requestPath, clientIp);
            
            return chain.filter(exchange).then(Mono.fromRunnable(() -> {
                ServerHttpResponse response = exchange.getResponse();
                Instant endTime = Instant.now();
                Duration duration = Duration.between(startTime, endTime);
                
                log.info("Outgoing response: {} {} - Status: {} - Duration: {}ms",
                        method, requestPath, response.getStatusCode(), duration.toMillis());
            }));
        };
    }
}

