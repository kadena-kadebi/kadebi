
(module kadebi-wrapper GOVERNANCE
  (defconst TICKET_PROVIDER_ACCOUNT (hash "ticket-provider-account"))
  (defschema ticket
    account:string
    value:decimal
    quantity:integer
    used-quantity:integer
  )
  (defschema state
    nxt-ticket-id:integer
  )
  (deftable ticket-table:{ticket})
  (deftable state-table:{state})
  (defcap GOVERNANCE()
    (enforce-guard "free.admin-keyset")
  )
  (defcap PRIVATE_RESERVE()
    true
  )
  (defun create-private-guard()
    (require-capability (PRIVATE_RESERVE))
  )
  (defun create-reserve-guard()
    (create-user-guard (create-private-guard))
  )
  (defun enforce-account-owner(account:string)
    (enforce-guard (at "guard" (coin.details account)))
  )
  (defun init()
    (coin.create-account TICKET_PROVIDER_ACCOUNT (create-reserve-guard))
    (insert state-table "" {"nxt-ticket-id": 0})
  )
  (defun vote(payer:string mode:string round:integer account:string number:integer amount:decimal want-to-close-current-round:bool)
    (free.kadebi.vote payer mode round account number amount want-to-close-current-round)
  )
  (defun vote-using-ticket(mode:string round:integer account:string number:integer ticket-id:string quantity:integer want-to-close-current-round:bool)
    (enforce (> quantity 0) "quantity must be positive")
    (enforce-account-owner account)
    (install-capability (free.kadebi.VOTE))
    (with-read ticket-table ticket-id {"quantity":=cur-quantity, "used-quantity":=used-quantity, "value":=value}
      (let ((remain-quantity (- cur-quantity used-quantity)) (total (* quantity value)))
        (install-capability (coin.TRANSFER TICKET_PROVIDER_ACCOUNT free.kadebi.CONTRACT_ACCOUNT total))
        (with-capability (PRIVATE_RESERVE)
          (enforce (<= quantity remain-quantity) "Remaining quantity is not enough")
          (free.kadebi.vote TICKET_PROVIDER_ACCOUNT mode round account number total want-to-close-current-round)
        )
      )
    )
  )
  (defun get-all-modes()
    (free.kadebi.get-all-modes)
  )
  (defun get-current-round(mode:string)
    (free.kadebi.get-current-round mode)
  )

  (defun round-details (mode:string round:integer)
    (free.kadebi.round-details mode round)
  )
  (defun get-all-tickets (account:string)
    (fold-db
      ticket-table
      (lambda (k obj) (and (= account (at "account" obj)) (< (at "used-quantity" obj) (at "quantity" obj))))
      (lambda (x) x))
  )
  (defun create-tickets (payer:string account:string value:decimal quantity:integer)
    (enforce (> value 0.0) "ticket value must be positive")
    (enforce (> quantity 0) "quantity must be positive")
    (let ((total (* value quantity)) (ticket-id (get-nxt-ticket-id)))
      (coin.transfer payer TICKET_PROVIDER_ACCOUNT total)
      (insert ticket-table (int-to-str 10 ticket-id) {"account": account, "quantity": quantity, "value": value, "used-quantity": 0})
      (update state-table "" {"nxt-ticket-id": (+ ticket-id 1)})
    )
  )
  (defun get-account-win-amount (mode:string round:integer account:string)
    (free.kadebi.get-account-win-amount mode round account)
  )
  (defun get-account-voted-amount-list(mode:string round:integer account:string)
    (free.kadebi.get-account-voted-amount-list mode round account)
  )
  (defun get-nxt-ticket-id ()
    (with-read state-table "" {"nxt-ticket-id":= nxt-ticket-id} nxt-ticket-id)
  )
)

(if (read-msg 'upgrade)
  ["upgrade"]
  [
    (create-table ticket-table)
    (create-table state-table)
    (init)
  ]
)
