;; Community Benefits Contract
;; Manages community benefit sharing and impact mitigation programs

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u500))
(define-constant ERR-INVALID-INPUT (err u501))
(define-constant ERR-PROJECT-NOT-FOUND (err u502))
(define-constant ERR-INSUFFICIENT-FUNDS (err u503))
(define-constant ERR-PROJECT-COMPLETED (err u504))
(define-constant ERR-INVALID-ALLOCATION (err u505))
(define-constant ERR-ALREADY-APPROVED (err u506))

;; Data Variables
(define-data-var next-project-id uint u1)
(define-data-var next-allocation-id uint u1)
(define-data-var total-community-fund uint u0)
(define-data-var total-allocated uint u0)
(define-data-var total-distributed uint u0)
(define-data-var contract-paused bool false)

;; Data Maps
(define-map community-projects
  uint
  {
    rights-id: uint,
    project-name: (string-ascii 100),
    project-type: (string-ascii 30),
    description: (string-ascii 300),
    requested-amount: uint,
    approved-amount: uint,
    allocated-amount: uint,
    distributed-amount: uint,
    beneficiary: principal,
    status: (string-ascii 20),
    created-date: uint,
    approved-date: (optional uint),
    completion-date: (optional uint),
    impact-metrics: (string-ascii 200)
  }
)

(define-map benefit-allocations
  uint
  {
    rights-id: uint,
    allocation-type: (string-ascii 30),
    amount: uint,
    percentage: uint,
    allocation-date: uint,
    source-extraction: uint,
    status: (string-ascii 20),
    distributed: bool
  }
)

(define-map rights-community-fund
  uint
  {
    total-fund: uint,
    allocated-fund: uint,
    distributed-fund: uint,
    pending-projects: uint,
    completed-projects: uint
  }
)

(define-map community-representatives
  principal
  {
    rights-id: uint,
    authorized: bool,
    appointed-date: uint
  }
)

(define-map impact-tracking
  uint
  {
    environmental-restoration: uint,
    local-employment: uint,
    infrastructure-development: uint,
    education-programs: uint,
    healthcare-initiatives: uint,
    last-updated: uint
  }
)

;; Private Functions
(define-private (is-valid-project-type (project-type (string-ascii 30)))
  (or
    (is-eq project-type "environmental-restoration")
    (is-eq project-type "infrastructure")
    (is-eq project-type "education")
    (is-eq project-type "healthcare")
    (is-eq project-type "local-employment")
    (is-eq project-type "community-facility")
    (is-eq project-type "cultural-preservation")
    (is-eq project-type "economic-development")
  )
)

(define-private (is-valid-allocation-type (allocation-type (string-ascii 30)))
  (or
    (is-eq allocation-type "extraction-percentage")
    (is-eq allocation-type "fixed-amount")
    (is-eq allocation-type "impact-mitigation")
    (is-eq allocation-type "community-development")
    (is-eq allocation-type "environmental-fund")
  )
)

(define-private (is-community-representative (rights-id uint) (representative principal))
  (match (map-get? community-representatives representative)
    rep-data (and (is-eq (get rights-id rep-data) rights-id) (get authorized rep-data))
    false
  )
)

(define-private (calculate-allocation-amount (extraction-value uint) (percentage uint))
  (/ (* extraction-value percentage) u100)
)

(define-private (update-rights-fund (rights-id uint) (amount uint) (operation (string-ascii 10)))
  (let ((current-fund (default-to {total-fund: u0, allocated-fund: u0, distributed-fund: u0, pending-projects: u0, completed-projects: u0}
                                 (map-get? rights-community-fund rights-id))))
    (if (is-eq operation "add")
      (map-set rights-community-fund rights-id (merge current-fund {
        total-fund: (+ (get total-fund current-fund) amount)
      }))
      (if (is-eq operation "allocate")
        (map-set rights-community-fund rights-id (merge current-fund {
          allocated-fund: (+ (get allocated-fund current-fund) amount)
        }))
        (if (is-eq operation "distribute")
          (map-set rights-community-fund rights-id (merge current-fund {
            distributed-fund: (+ (get distributed-fund current-fund) amount)
          }))
          false
        )
      )
    )
  )
)

(define-private (update-impact-metrics (rights-id uint) (project-type (string-ascii 30)) (amount uint))
  (let ((current-impact (default-to {environmental-restoration: u0, local-employment: u0, infrastructure-development: u0, education-programs: u0, healthcare-initiatives: u0, last-updated: u0}
                                   (map-get? impact-tracking rights-id))))
    (map-set impact-tracking rights-id (merge current-impact {
      environmental-restoration: (if (is-eq project-type "environmental-restoration") (+ (get environmental-restoration current-impact) amount) (get environmental-restoration current-impact)),
      local-employment: (if (is-eq project-type "local-employment") (+ (get local-employment current-impact) amount) (get local-employment current-impact)),
      infrastructure-development: (if (is-eq project-type "infrastructure") (+ (get infrastructure-development current-impact) amount) (get infrastructure-development current-impact)),
      education-programs: (if (is-eq project-type "education") (+ (get education-programs current-impact) amount) (get education-programs current-impact)),
      healthcare-initiatives: (if (is-eq project-type "healthcare") (+ (get healthcare-initiatives current-impact) amount) (get healthcare-initiatives current-impact)),
      last-updated: block-height
    }))
  )
)

;; Public Functions

;; Allocate community benefits from extraction
(define-public (allocate-benefits
  (rights-id uint)
  (extraction-value uint)
  (allocation-percentage uint)
  (allocation-type (string-ascii 30))
  (source-extraction uint)
)
  (let (
    (allocation-id (var-get next-allocation-id))
    (allocation-amount (calculate-allocation-amount extraction-value allocation-percentage))
  )
    ;; Validate inputs
    (asserts! (not (var-get contract-paused)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED) ;; Only contract owner for now
    (asserts! (is-valid-allocation-type allocation-type) ERR-INVALID-INPUT)
    (asserts! (> extraction-value u0) ERR-INVALID-INPUT)
    (asserts! (<= allocation-percentage u50) ERR-INVALID-ALLOCATION) ;; Max 50%
    (asserts! (> allocation-percentage u0) ERR-INVALID-ALLOCATION)

    ;; Create allocation record
    (map-set benefit-allocations allocation-id {
      rights-id: rights-id,
      allocation-type: allocation-type,
      amount: allocation-amount,
      percentage: allocation-percentage,
      allocation-date: block-height,
      source-extraction: source-extraction,
      status: "allocated",
      distributed: false
    })

    ;; Update community fund
    (update-rights-fund rights-id allocation-amount "add")

    ;; Update global counters
    (var-set next-allocation-id (+ allocation-id u1))
    (var-set total-community-fund (+ (var-get total-community-fund) allocation-amount))
    (var-set total-allocated (+ (var-get total-allocated) allocation-amount))

    (ok allocation-id)
  )
)

;; Submit community project proposal
(define-public (submit-project-proposal
  (rights-id uint)
  (project-name (string-ascii 100))
  (project-type (string-ascii 30))
  (description (string-ascii 300))
  (requested-amount uint)
  (beneficiary principal)
)
  (let ((project-id (var-get next-project-id)))
    ;; Validate inputs
    (asserts! (is-community-representative rights-id tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-valid-project-type project-type) ERR-INVALID-INPUT)
    (asserts! (> requested-amount u0) ERR-INVALID-INPUT)

    ;; Create project record
    (map-set community-projects project-id {
      rights-id: rights-id,
      project-name: project-name,
      project-type: project-type,
      description: description,
      requested-amount: requested-amount,
      approved-amount: u0,
      allocated-amount: u0,
      distributed-amount: u0,
      beneficiary: beneficiary,
      status: "proposed",
      created-date: block-height,
      approved-date: none,
      completion-date: none,
      impact-metrics: ""
    })

    ;; Update project counter
    (var-set next-project-id (+ project-id u1))

    (ok project-id)
  )
)

;; Approve community project
(define-public (approve-project (project-id uint) (approved-amount uint))
  (let ((project-data (unwrap! (map-get? community-projects project-id) ERR-PROJECT-NOT-FOUND)))
    ;; Validate authorization
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status project-data) "proposed") ERR-ALREADY-APPROVED)
    (asserts! (> approved-amount u0) ERR-INVALID-INPUT)
    (asserts! (<= approved-amount (get requested-amount project-data)) ERR-INVALID-INPUT)

    ;; Check available funds
    (let ((rights-fund (default-to {total-fund: u0, allocated-fund: u0, distributed-fund: u0, pending-projects: u0, completed-projects: u0}
                                  (map-get? rights-community-fund (get rights-id project-data)))))
      (asserts! (>= (- (get total-fund rights-fund) (get allocated-fund rights-fund)) approved-amount) ERR-INSUFFICIENT-FUNDS)

      ;; Update project record
      (map-set community-projects project-id (merge project-data {
        approved-amount: approved-amount,
        allocated-amount: approved-amount,
        status: "approved",
        approved-date: (some block-height)
      }))

      ;; Update fund allocation
      (update-rights-fund (get rights-id project-data) approved-amount "allocate")

      (ok true)
    )
  )
)

;; Distribute project funds
(define-public (distribute-project-funds (project-id uint))
  (let ((project-data (unwrap! (map-get? community-projects project-id) ERR-PROJECT-NOT-FOUND)))
    ;; Validate authorization and status
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status project-data) "approved") ERR-INVALID-INPUT)
    (asserts! (> (get allocated-amount project-data) u0) ERR-INVALID-INPUT)

    ;; In real implementation, this would transfer STX to beneficiary
    ;; For now, just update the record
    (map-set community-projects project-id (merge project-data {
      distributed-amount: (get allocated-amount project-data),
      status: "funded"
    }))

    ;; Update fund tracking
    (update-rights-fund (get rights-id project-data) (get allocated-amount project-data) "distribute")

    ;; Update impact metrics
    (update-impact-metrics (get rights-id project-data) (get project-type project-data) (get allocated-amount project-data))

    ;; Update global counter
    (var-set total-distributed (+ (var-get total-distributed) (get allocated-amount project-data)))

    (ok (get allocated-amount project-data))
  )
)

;; Complete project
(define-public (complete-project (project-id uint) (impact-metrics (string-ascii 200)))
  (let ((project-data (unwrap! (map-get? community-projects project-id) ERR-PROJECT-NOT-FOUND)))
    ;; Validate authorization
    (asserts! (or (is-eq tx-sender CONTRACT-OWNER) (is-community-representative (get rights-id project-data) tx-sender)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status project-data) "funded") ERR-INVALID-INPUT)

    ;; Update project record
    (map-set community-projects project-id (merge project-data {
      status: "completed",
      completion-date: (some block-height),
      impact-metrics: impact-metrics
    }))

    (ok true)
  )
)

;; Appoint community representative
(define-public (appoint-community-representative (rights-id uint) (representative principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)

    (map-set community-representatives representative {
      rights-id: rights-id,
      authorized: true,
      appointed-date: block-height
    })

    (ok true)
  )
)

;; Read-only Functions

;; Get project information
(define-read-only (get-project-info (project-id uint))
  (map-get? community-projects project-id)
)

;; Get allocation information
(define-read-only (get-allocation-info (allocation-id uint))
  (map-get? benefit-allocations allocation-id)
)

;; Get community fund status
(define-read-only (get-community-fund-status (rights-id uint))
  (map-get? rights-community-fund rights-id)
)

;; Get impact metrics
(define-read-only (get-impact-metrics (rights-id uint))
  (map-get? impact-tracking rights-id)
)

;; Check community representative
(define-read-only (is-authorized-representative (rights-id uint) (representative principal))
  (is-community-representative rights-id representative)
)

;; Get available funds for rights
(define-read-only (get-available-funds (rights-id uint))
  (match (map-get? rights-community-fund rights-id)
    fund-data (- (get total-fund fund-data) (get allocated-fund fund-data))
    u0
  )
)

;; Get contract statistics
(define-read-only (get-contract-stats)
  {
    total-community-fund: (var-get total-community-fund),
    total-allocated: (var-get total-allocated),
    total-distributed: (var-get total-distributed),
    total-projects: (- (var-get next-project-id) u1),
    contract-paused: (var-get contract-paused)
  }
)

;; Admin Functions

;; Set contract paused
(define-public (set-contract-paused (paused bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set contract-paused paused)
    (ok paused)
  )
)

;; Emergency fund withdrawal
(define-public (emergency-withdraw (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (<= amount (var-get total-community-fund)) ERR-INSUFFICIENT-FUNDS)

    ;; In real implementation, this would transfer STX
    (var-set total-community-fund (- (var-get total-community-fund) amount))
    (ok amount)
  )
)
