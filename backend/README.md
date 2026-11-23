# SurakshaPath - Backend & Data Sync Specifications

## Overview
This directory holds backend schema definitions, sample mock endpoints, and offline cache synchronization strategies for SurakshaPath.

## REST / Firestore Collections
1. `/shelters`
   - `id`: string
   - `name`: string
   - `latitude`: double
   - `longitude`: double
   - `capacityTotal`: integer
   - `capacityOccupied`: integer
   - `status`: "open" | "near_full" | "full" | "closed"
   - `contactNumber`: string
   - `facilities`: array<string>
   - `isVerified`: boolean

2. `/alerts`
   - `id`: string
   - `title`: string
   - `description`: string
   - `disasterType`: "cyclone" | "flood" | "fire" | "earthquake" | "landslide" | "tsunami"
   - `severity`: "advisory" | "watch" | "warning" | "critical"
   - `affectedArea`: string
   - `issuedAt`: ISO8601 string
   - `expiresAt`: ISO8601 string
   - `source`: string

3. `/sos_broadcast`
   - `userId`: string
   - `timestamp`: ISO8601 string
   - `latitude`: double
   - `longitude`: double
   - `accuracy`: double
   - `status`: "active" | "dispatched" | "resolved"
