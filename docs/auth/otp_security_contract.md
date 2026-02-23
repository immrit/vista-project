# OTP Security Contract (Client/Server)

This document defines the client contract for OTP abuse protection.

## Scope
- Endpoint family: `send-otp`, `verify-otp`, `reset-password-sms`
- Goal: rate-limit + challenge to reduce brute-force and SMS abuse

## Required Headers
- `X-Device-Id`: stable device identifier (hashed on client side)
- `X-Auth-Challenge`: challenge token issued by backend
- `X-Auth-Nonce`: one-time nonce for replay protection

## Client Payload Rules
- `phone_number` must be normalized to local format `09xxxxxxxxx`
- Never send empty or null values for auth identifiers
- Retry must respect server cooldown and lockout metadata

## Server Rate Limit Requirements
- Rate-limit key must include at least:
  - normalized phone number
  - device id
  - source IP/network bucket
- Progressive backoff after repeated failures
- Temporary lock after threshold failures

## Standard Error Codes (Expected by Client)
- `OTP_RATE_LIMITED`
- `OTP_CHALLENGE_REQUIRED`
- `OTP_CHALLENGE_FAILED`
- `OTP_INVALID`
- `OTP_EXPIRED`
- `OTP_LOCKED`

## Response Metadata (Recommended)
- `retry_after_seconds`
- `attempts_remaining`
- `lock_expires_at`
- `challenge_required` (boolean)

## Logging & Privacy
- No plaintext logging of OTP codes
- No plaintext logging of full phone numbers
- Keep only masked values in user-visible messages
