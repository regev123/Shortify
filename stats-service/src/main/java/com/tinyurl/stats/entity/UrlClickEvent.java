package com.tinyurl.stats.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Entity
@Table(name = "url_click_events", indexes = {
    @Index(name = "idx_short_code", columnList = "shortCode"),
    @Index(name = "idx_clicked_at", columnList = "clickedAt"),
    @Index(name = "idx_short_code_clicked_at", columnList = "shortCode,clickedAt")
})
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UrlClickEvent {
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(nullable = false, length = 10)
    private String shortCode;
    
    @Column(nullable = false)
    private LocalDateTime clickedAt;
    
    @Column(length = 100)
    private String country;
    
    @Column(length = 100)
    private String city;
    
    @Column(length = 500)
    private String userAgent; // Browser user agents can be very long
    
    @Column(length = 50)
    private String deviceType; // MOBILE, DESKTOP, TABLET
    
    @Column(length = 1000)
    private String referrer; // URLs can be very long
    
    @Column(length = 100)
    private String ipAddress; // IPv6 addresses can be up to 45 chars, but allow extra space
}

