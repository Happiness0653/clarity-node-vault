;; NodeVault - Decentralized Node Management System

;; Constants
(define-constant contract-owner tx-sender)
(define-constant min-stake-amount u50000)
(define-constant reward-cycle-length u144) ;; ~1 day in blocks
(define-constant min-uptime u95) ;; 95% minimum uptime
(define-constant blocks-per-cycle u144)

;; Error codes  
(define-constant err-unauthorized (err u100))
(define-constant err-insufficient-stake (err u101))
(define-constant err-already-registered (err u102))
(define-constant err-not-registered (err u103))
(define-constant err-invalid-uptime (err u104))
(define-constant err-no-stake (err u105))
(define-constant err-cycle-not-complete (err u106))

;; Data variables
(define-map operators 
  principal 
  {name: (string-ascii 50),
   stake-amount: uint,
   total-uptime: uint,
   reputation-score: uint,
   last-reward-cycle: uint,
   registration-height: uint})

(define-data-var total-staked uint u0)
(define-data-var current-cycle uint u0)

;; SIP-010 Token for staking
(define-fungible-token node-token)

;; Admin functions
(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
    (ft-mint? node-token amount recipient)))

;; Public functions
(define-public (register-operator (name (string-ascii 50)) (stake-amount uint))
  (let ((operator tx-sender))
    (asserts! (is-none (map-get? operators operator)) err-already-registered)
    (asserts! (>= stake-amount min-stake-amount) err-insufficient-stake)
    
    (try! (ft-transfer? node-token stake-amount operator (as-contract tx-sender)))
    
    (map-set operators operator 
      {name: name,
       stake-amount: stake-amount,
       total-uptime: u0,
       reputation-score: u100,
       last-reward-cycle: (var-get current-cycle),
       registration-height: block-height})
    
    (var-set total-staked (+ (var-get total-staked) stake-amount))
    (ok true)))

(define-public (stake-tokens (amount uint))
  (let ((operator tx-sender)
        (current-info (unwrap! (map-get? operators operator) err-not-registered)))
    
    (try! (ft-transfer? node-token amount operator (as-contract tx-sender)))
    
    (map-set operators operator 
      (merge current-info 
        {stake-amount: (+ (get stake-amount current-info) amount)}))
        
    (var-set total-staked (+ (var-get total-staked) amount))
    (ok true)))

(define-public (withdraw-stake (amount uint))
  (let ((operator tx-sender)
        (current-info (unwrap! (map-get? operators operator) err-not-registered)))
    (asserts! (<= amount (get stake-amount current-info)) err-insufficient-stake)
    (asserts! (>= (- (get stake-amount current-info) amount) min-stake-amount) err-insufficient-stake)
    
    (try! (as-contract (ft-transfer? node-token amount (as-contract tx-sender) operator)))
    
    (map-set operators operator 
      (merge current-info 
        {stake-amount: (- (get stake-amount current-info) amount)}))
        
    (var-set total-staked (- (var-get total-staked) amount))
    (ok true)))

(define-public (record-uptime (operator principal) (uptime uint))
  (let ((current-info (unwrap! (map-get? operators operator) err-not-registered)))
    (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
    (asserts! (<= uptime u100) err-invalid-uptime)
    
    (map-set operators operator
      (merge current-info 
        {total-uptime: (+ (get total-uptime current-info) uptime)}))
    (ok true)))

(define-public (claim-rewards)
  (let ((operator tx-sender)
        (current-info (unwrap! (map-get? operators operator) err-not-registered))
        (last-cycle (get last-reward-cycle current-info))
        (current (get-current-cycle)))
    
    (asserts! (> current last-cycle) err-cycle-not-complete)
    
    (if (>= (get total-uptime current-info) min-uptime)
      (let ((reward-amount (calculate-reward (get stake-amount current-info))))
        (try! (ft-mint? node-token reward-amount operator))
        (map-set operators operator
          (merge current-info 
            {last-reward-cycle: current,
             total-uptime: u0}))
        (ok reward-amount))
      (ok u0))))

;; Read only functions
(define-read-only (get-operator-info (operator principal))
  (ok (map-get? operators operator)))

(define-read-only (get-total-staked)
  (ok (var-get total-staked)))

(define-read-only (get-current-cycle)
  (/ block-height blocks-per-cycle))

;; Internal functions
(define-private (calculate-reward (stake-amount uint))
  (/ (* stake-amount u5) u100)) ;; 5% reward
