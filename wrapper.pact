
(module kadebi-wrapper "free.admin-keyset"
  (defschema ticket
    account:string
    value:decimal
    quantity:integer
    used-quantity:integer
  )
  (deftable ticket-table:{ticket})
  (defun vote(mode:string round:integer account:string number:integer amount:decimal) true)
  (defun vote-using-ticket(mode:string round:integer account:string number:integer ticket-id:string quantity:integer) true)
  (defun get-all-modes() true)
  (defun get-current-round(mode:string) true)
  (defun get-voted-amount-by-account(mode:string round:integer account:string) true)
  (defun round-details (mode:string round:integer) true)
  (defun get-all-tickets (account:string) true)
  (defun get-winning-amount (mode:string round:integer account:string) true)
)
