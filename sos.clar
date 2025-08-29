(define-data-var owner principal tx-sender)

;; Mechanic struct: stores mechanic info and verification status
(define-map mechanics
    principal ;; mechanic's Stacks address
    {
        name: (string-ascii 50),
        phone: (string-ascii 20),
        location: (string-ascii 100),
        verified: bool,
        total-ratings: uint,
        ratings-count: uint,
    }
)

;; SOS requests: map from driver principal to mechanic principal
(define-map sos-requests
    principal ;; driver
    {
        mechanic: principal,
        timestamp: uint,
    }
)

;; Only owner can call
(define-private (is-owner (sender principal))
    (is-eq sender (var-get owner))
)

;; Register mechanic (anyone can call to register themselves)
(define-public (register-mechanic
        (name (string-ascii 50))
        (phone (string-ascii 20))
        (location (string-ascii 100))
    )
    (begin
        (match (map-get? mechanics tx-sender)
            some-data (err u100) ;; already registered
            (begin
                (map-set mechanics tx-sender {
                    name: name,
                    phone: phone,
                    location: location,
                    verified: false,
                    total-ratings: u0,
                    ratings-count: u0,
                })
                (ok true)
            )
        )
    )
)

;; Owner verifies mechanic
(define-public (verify-mechanic (mechanic principal))
    (begin
        (asserts! (is-owner tx-sender) (err u101))
        (match (map-get? mechanics mechanic)
            data (begin
                (map-set mechanics mechanic {
                    name: (get name data),
                    phone: (get phone data),
                    location: (get location data),
                    verified: true,
                    total-ratings: (get total-ratings data),
                    ratings-count: (get ratings-count data),
                })
                (ok true)
            )
            (err u102) ;; mechanic not found
        )
    )
)

;; Driver sends SOS request to a verified mechanic
(define-public (send-sos (mechanic principal))
    (begin
        (match (map-get? mechanics mechanic)
            data (if (get verified data)
                (begin
                    (map-set sos-requests tx-sender {
                        mechanic: mechanic,
                        timestamp: u0, ;; Using u0 as placeholder since block-height not available
                    })
                    (ok true)
                )
                (err u103) ;; mechanic not verified
            )
            (err u102) ;; mechanic not found
        )
    )
)

;; Driver rates mechanic after service (rating 1 to 5)
(define-public (rate-mechanic
        (mechanic principal)
        (rating uint)
    )
    (begin
        (asserts! (and (>= rating u1) (<= rating u5)) (err u104))
        ;; Check if driver had an SOS request with this mechanic
        (match (map-get? sos-requests tx-sender)
            req (if (is-eq (get mechanic req) mechanic)
                (match (map-get? mechanics mechanic)
                    data (let (
                            (new-total (+ (get total-ratings data) rating))
                            (new-count (+ (get ratings-count data) u1))
                        )
                        (map-set mechanics mechanic {
                            name: (get name data),
                            phone: (get phone data),
                            location: (get location data),
                            verified: (get verified data),
                            total-ratings: new-total,
                            ratings-count: new-count,
                        })
                        (ok true)
                    )
                    (err u102)
                )
                (err u105) ;; no SOS request with this mechanic
            )
            (err u106) ;; no SOS request found
        )
    )
)

;; Get mechanic average rating (read-only)
(define-read-only (get-average-rating (mechanic principal))
    (match (map-get? mechanics mechanic)
        data (let ((count (get ratings-count data)))
            (if (> count u0)
                (ok (/ (get total-ratings data) count))
                (ok u0)
            )
        )
        (err u102)
    )
)

;; Get mechanic info (read-only)
(define-read-only (get-mechanic (mechanic principal))
    (match (map-get? mechanics mechanic)
        data (ok data)
        (err u102)
    )
)