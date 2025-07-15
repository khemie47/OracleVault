;; OracleVault - Decentralized Prediction Market Platform
;; This contract enables users to create prophecy markets, stake predictions, and resolve outcomes.

;; Define core data structures
(define-data-var prophecy-counter uint u0) ;; Auto-incrementing prophecy ID
(define-data-var vault-guardian principal tx-sender)
(define-data-var emergency-halt uint u0) ;; 0 = active, 1 = halted

(define-map prophecies { id: uint } { oracle: principal, vision: (string-ascii 100), revelation: (optional bool), sealed: bool, deadline: uint })
(define-map stakes { prophecy-id: uint, prophet: principal } { wager: uint, prediction: bool })
(define-map prediction-vaults { prophecy-id: uint, prediction: bool } { treasury: uint })

(define-constant ORACLE_TAX u100) ;; Tax in microSTX (e.g., 100 microSTX = 0.0001 STX)
(define-constant TAX_COLLECTOR 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE)
(define-constant MIN_DEADLINE_BLOCKS u100) ;; Minimum number of blocks for prophecy deadline
(define-constant MAX_DEADLINE_BLOCKS u52560) ;; Maximum number of blocks (approximately 1 year)
(define-constant MIN_STAKE_AMOUNT u1000) ;; Minimum stake amount in microSTX
(define-constant MAX_STAKE_AMOUNT u1000000000) ;; Maximum stake amount in microSTX

;; Error codes
(define-constant ERR_NOT_ORACLE (err u100))
(define-constant ERR_PROPHECY_SEALED (err u101))
(define-constant ERR_PROPHECY_NOT_SEALED (err u102))
(define-constant ERR_INVALID_STAKE (err u103))
(define-constant ERR_INSUFFICIENT_FUNDS (err u104))
(define-constant ERR_PROPHECY_EXPIRED (err u105))
(define-constant ERR_REFUND_FORBIDDEN (err u106))
(define-constant ERR_NOT_AUTHORIZED (err u107))
(define-constant ERR_EMERGENCY_HALT (err u108))
(define-constant ERR_INVALID_DEADLINE (err u109))
(define-constant ERR_INVALID_WAGER (err u110))
(define-constant ERR_INVALID_GUARDIAN (err u111))
(define-constant ERR_INVALID_PROPHECY_ID (err u112))
(define-constant ERR_INVALID_VISION (err u113))

;; Read-only helper to check emergency halt status
(define-read-only (is-halted)
    (is-eq (var-get emergency-halt) u1)
)

;; Helper to validate prophecy ID
(define-private (is-valid-prophecy-id (prophecy-identifier uint))
    (<= prophecy-identifier (var-get prophecy-counter))
)

;; Helper to validate vision string
(define-private (is-valid-vision (vision (string-ascii 100)))
    (and 
        (>= (len vision) u1)
        (<= (len vision) u100)
    )
)

;; Guardian-only function to toggle emergency halt
(define-public (toggle-emergency-halt)
    (begin
        (asserts! (is-eq tx-sender (var-get vault-guardian)) ERR_NOT_AUTHORIZED)
        (ok (var-set emergency-halt (if (is-halted) u0 u1)))
    )
)

;; Get comprehensive prophecy information
(define-read-only (get-prophecy-details (prophecy-identifier uint))
    (begin
        (asserts! (is-valid-prophecy-id prophecy-identifier) ERR_INVALID_PROPHECY_ID)
        (let ((prophecy (map-get? prophecies { id: prophecy-identifier })))
            (if (is-some prophecy)
                (let ((prophecy-data (unwrap-panic prophecy))
                      (true-vault (default-to u0 (get treasury (map-get? prediction-vaults { prophecy-id: prophecy-identifier, prediction: true }))))
                      (false-vault (default-to u0 (get treasury (map-get? prediction-vaults { prophecy-id: prophecy-identifier, prediction: false })))))
                    (ok {
                        oracle: (get oracle prophecy-data),
                        vision: (get vision prophecy-data),
                        revelation: (get revelation prophecy-data),
                        sealed: (get sealed prophecy-data),
                        deadline: (get deadline prophecy-data),
                        true-vault: true-vault,
                        false-vault: false-vault,
                        total-treasury: (+ true-vault false-vault)
                    })
                )
                ERR_INVALID_STAKE
            )
        )
    )
)

;; Calculate potential rewards
(define-read-only (calculate-potential-rewards (prophecy-identifier uint) (stake-amount uint) (prediction bool))
    (begin
        (asserts! (is-valid-prophecy-id prophecy-identifier) ERR_INVALID_PROPHECY_ID)
        (asserts! (and (>= stake-amount MIN_STAKE_AMOUNT) (<= stake-amount MAX_STAKE_AMOUNT)) ERR_INVALID_WAGER)
        (let ((prophecy (map-get? prophecies { id: prophecy-identifier })))
            (if (is-some prophecy)
                (let ((prophecy-data (unwrap-panic prophecy))
                      (chosen-vault (default-to u0 (get treasury (map-get? prediction-vaults { prophecy-id: prophecy-identifier, prediction: prediction }))))
                      (opposite-vault (default-to u0 (get treasury (map-get? prediction-vaults { prophecy-id: prophecy-identifier, prediction: (not prediction )}))))
                      (total-treasury (+ chosen-vault opposite-vault)))
                    (if (> total-treasury u0)
                        (ok (/ (* stake-amount total-treasury) chosen-vault))
                        (ok stake-amount)
                    )
                )
                ERR_INVALID_STAKE
            )
        )
    )
)

;; Transfer guardian privileges
(define-public (transfer-guardianship (new-guardian principal))
    (begin
        (asserts! (is-eq tx-sender (var-get vault-guardian)) ERR_NOT_AUTHORIZED)
        (asserts! (not (is-eq new-guardian tx-sender)) ERR_INVALID_GUARDIAN)
        (asserts! (not (is-eq new-guardian (var-get vault-guardian))) ERR_INVALID_GUARDIAN)
        (var-set vault-guardian new-guardian)
        (ok true)
    )
)

;; Create a new prophecy market
(define-public (create-prophecy (vision (string-ascii 100)) (deadline uint))
    (begin
        (asserts! (not (is-halted)) ERR_EMERGENCY_HALT)
        (asserts! (is-valid-vision vision) ERR_INVALID_VISION)
        (asserts! (and 
            (>= deadline (+ block-height MIN_DEADLINE_BLOCKS))
            (<= deadline (+ block-height MAX_DEADLINE_BLOCKS))) 
            ERR_INVALID_DEADLINE)
        (let ((id (var-get prophecy-counter)))
            (map-set prophecies 
                { id: id } 
                { 
                    oracle: tx-sender, 
                    vision: vision, 
                    revelation: none, 
                    sealed: false, 
                    deadline: deadline 
                })
            (var-set prophecy-counter (+ id u1))
            (ok id)
        )
    )
)

;; Place a prediction stake
(define-public (place-stake (prophecy-identifier uint) (prediction bool) (wager uint))
    (begin
        (asserts! (not (is-halted)) ERR_EMERGENCY_HALT)
        (asserts! (is-valid-prophecy-id prophecy-identifier) ERR_INVALID_PROPHECY_ID)
        (asserts! (and (>= wager MIN_STAKE_AMOUNT) (<= wager MAX_STAKE_AMOUNT)) ERR_INVALID_WAGER)
        (let (
            (prophecy (map-get? prophecies { id: prophecy-identifier })))
            (asserts! (is-some prophecy) ERR_INVALID_STAKE)
            (let (
                (prophecy-data (unwrap-panic prophecy))
                (sealed (get sealed prophecy-data))
                (deadline (get deadline prophecy-data))
                (current-vault (default-to { treasury: u0 } (map-get? prediction-vaults { prophecy-id: prophecy-identifier, prediction: prediction }))))
                (asserts! (not sealed) ERR_PROPHECY_SEALED)
                (asserts! (> deadline block-height) ERR_PROPHECY_EXPIRED)
                (asserts! (>= (stx-get-balance tx-sender) (+ wager ORACLE_TAX)) ERR_INSUFFICIENT_FUNDS)
                (map-set stakes { prophecy-id: prophecy-identifier, prophet: tx-sender } { wager: wager, prediction: prediction })
                (map-set prediction-vaults { prophecy-id: prophecy-identifier, prediction: prediction } { treasury: (+ (get treasury current-vault) wager) })
                (try! (stx-transfer? wager tx-sender (as-contract tx-sender)))
                (try! (stx-transfer? ORACLE_TAX tx-sender TAX_COLLECTOR))
                (ok true)
            )
        )
    )
)

;; Seal prophecy with revelation
(define-public (seal-prophecy (prophecy-identifier uint) (revelation bool))
    (begin
        (asserts! (is-valid-prophecy-id prophecy-identifier) ERR_INVALID_PROPHECY_ID)
        (let (
            (prophecy (map-get? prophecies { id: prophecy-identifier })))
            (asserts! (is-some prophecy) ERR_INVALID_STAKE)
            (let (
                (prophecy-data (unwrap-panic prophecy))
                (oracle (get oracle prophecy-data))
                (sealed (get sealed prophecy-data)))
                (asserts! (is-eq tx-sender oracle) ERR_NOT_ORACLE)
                (asserts! (not sealed) ERR_PROPHECY_SEALED)
                (map-set prophecies 
                    { id: prophecy-identifier } 
                    { 
                        oracle: oracle, 
                        vision: (get vision prophecy-data), 
                        revelation: (some revelation), 
                        sealed: true, 
                        deadline: (get deadline prophecy-data) 
                    }
                )
                (ok true)
            )
        )
    )
)

;; Claim prophecy rewards
(define-public (claim-rewards (prophecy-identifier uint))
    (begin
        (asserts! (is-valid-prophecy-id prophecy-identifier) ERR_INVALID_PROPHECY_ID)
        (let (
            (prophecy (map-get? prophecies { id: prophecy-identifier })))
            (asserts! (is-some prophecy) ERR_INVALID_STAKE)
            (let (
                (prophecy-data (unwrap-panic prophecy))
                (sealed (get sealed prophecy-data))
                (prophecy-revelation (get revelation prophecy-data))
                (stake (map-get? stakes { prophecy-id: prophecy-identifier, prophet: tx-sender })))
                (asserts! sealed ERR_PROPHECY_NOT_SEALED)
                (asserts! (is-some prophecy-revelation) ERR_PROPHECY_NOT_SEALED)
                (asserts! (is-some stake) ERR_INVALID_STAKE)
                (let (
                    (stake-data (unwrap-panic stake))
                    (wager (get wager stake-data))
                    (stake-prediction (get prediction stake-data)))
                    (asserts! (is-eq stake-prediction (unwrap-panic prophecy-revelation)) ERR_INVALID_STAKE)
                    (map-delete stakes { prophecy-id: prophecy-identifier, prophet: tx-sender })
                    (try! (stx-transfer? wager (as-contract tx-sender) tx-sender))
                    (ok true)
                )
            )
        )
    )
)

;; Refund expired stake
(define-public (refund-stake (prophecy-identifier uint))
    (begin
        (asserts! (is-valid-prophecy-id prophecy-identifier) ERR_INVALID_PROPHECY_ID)
        (let (
            (prophecy (map-get? prophecies { id: prophecy-identifier })))
            (asserts! (is-some prophecy) ERR_INVALID_STAKE)
            (let (
                (prophecy-data (unwrap-panic prophecy))
                (sealed (get sealed prophecy-data))
                (deadline (get deadline prophecy-data))
                (stake (map-get? stakes { prophecy-id: prophecy-identifier, prophet: tx-sender })))
                (asserts! (not sealed) ERR_PROPHECY_SEALED)
                (asserts! (<= deadline block-height) ERR_REFUND_FORBIDDEN)
                (asserts! (is-some stake) ERR_INVALID_STAKE)
                (let (
                    (stake-data (unwrap-panic stake))
                    (wager (get wager stake-data)))
                    (map-delete stakes { prophecy-id: prophecy-identifier, prophet: tx-sender })
                    (try! (stx-transfer? wager (as-contract tx-sender) tx-sender))
                    (ok true)
                )
            )
        )
    )
)