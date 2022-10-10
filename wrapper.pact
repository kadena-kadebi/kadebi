
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
    (enforce-guard (PRIVATE_RESERVE))
  )
  (defun create-reserve-guard()
    (create-user-guard (create-private-guard))
  )
  (defun init()
    (coin.create-account TICKET_PROVIDER_ACCOUNT (create-reserve-guard))
    (insert state-table "" {"nxt-ticket-id": 0})
  )
  (defun vote(mode:string round:integer account:string number:integer amount:decimal want-to-close-current-round:bool)
    (free.kadebi.vote mode round account number amount want-to-close-current-round)
  )
  (defun vote-using-ticket(mode:string round:integer account:string number:integer ticket-id:string quantity:integer) true)
  (defun get-all-modes()
    (free.kadebi.get-all-modes)
  )
  (defun get-current-round(mode:string)
    (free.kadebi.get-current-round mode)
  )
  (defun get-voted-amount-by-account(mode:string round:integer account:string) true)
  (defun round-details (mode:string round:integer)
    (free.kadebi.round-details mode round)
  )
  (defun get-all-tickets (account:string)
    (fold-db
      ticket-table
      (lambda (k obj) (and (= account (at "account" obj)) (< (at "used-quantity" obj) (at "quantity" obj))))
      (lambda (x) x))
  )
  (defun create-tickets (buyer:string account:string value:decimal quantity:integer)
    (let ((total (* value quantity)) (ticket-id (get-nxt-ticket-id)))
      (install-capability (coin.TRANSFER buyer TICKET_PROVIDER_ACCOUNT total))
      (with-capability (PRIVATE_RESERVE)
        (coin.transfer account TICKET_PROVIDER_ACCOUNT total)
        (insert ticket-table (int-to-str 10 ticket-id) {"account": account, "quantity": quantity, "value": value, "used-quantity": 0})
        (update state-table "" {"nxt-ticket-id": (+ ticket-id 1)})
      )
    )
  )
  (defun get-account-win-amount (mode:string round:integer account:string)
    (free.kadebi.get-account-win-amount mode round account)
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
