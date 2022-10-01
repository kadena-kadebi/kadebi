(namespace 'free)
(define-keyset "free.admin-keyset" (read-keyset "admin-keyset"))
(module kadebi GOVERNANCE
  (defconst CONTRACT_ACCOUNT (hash "kadebi-coin-account"))
  (defconst ROUND_DURATION (* 5.0 60))
  (defconst BURN_RATE 0.05)
  (defconst HOUSE_ERN_RATE 0.1)
  (defconst RETURN_RATE (- 1 (+ BURN_RATE HOUSE_ERN_RATE)))
  (defconst BURN_ACCOUNT "k:0000000000000000000000000000000000000000000000000000000000000000")
  (defconst STATE_KEY "state")
  (defconst PHASE_ONE:string "phase1")
  (defconst PHASE_TWO:string "phase2")
  (defconst MULTIPLYER:integer 6364136223846793005)
  (defconst INCREMENT:integer 1442695040888963407)
  (defconst MODULES:integer (- (^ 2 64) 1))
  (defconst CHAR_MAP {"0":48,"1":49,"2":50,"3":51,"4":52,"5":53,"6":54,"7":55,"8":56,"9":57," ":32,"!":33,"\"":34,"#":35,"$":36,"%":37,"&":38,"\'":39,"(":40,")":41,"*":42,"+":43,",":44,"-":45,".":46,"/":47,":":58,";":59,"<":60,"=":61,">":62,"?":63,"@":64,"A":65,"B":66,"C":67,"D":68,"E":69,"F":70,"G":71,"H":72,"I":73,"J":74,"K":75,"L":76,"M":77,"N":78,"O":79,"P":80,"Q":81,"R":82,"S":83,"T":84,"U":85,"V":86,"W":87,"X":88,"Y":89,"Z":90,"[":91,"\\":92,"]":93,"^":94,"_":95,"`":96,"a":97,"b":98,"c":99,"d":100,"e":101,"f":102,"g":103,"h":104,"i":105,"j":106,"k":107,"l":108,"m":109,"n":110,"o":111,"p":112,"q":113,"r":114,"s":115,"t":116,"u":117,"v":118,"w":119,"x":120,"y":121,"z":122,"{":123,"|":124,"}":125,"~":126,"":127,"":128,"":129,"":130,"":131,"":132,"":133,"":134,"":135,"":136,"":137,"":138,"":139,"":140,"":141,"":142,"":143,"":144,"":145,"":146,"":147,"":148,"":149,"":150,"":151,"":152,"":153,"":154,"":155,"":156,"":157,"":158,"":159," ":160,"¡":161,"¢":162,"£":163,"¤":164,"¥":165,"¦":166,"§":167,"¨":168,"©":169,"ª":170,"«":171,"¬":172,"­":173,"®":174,"¯":175,"°":176,"±":177,"²":178,"³":179,"´":180,"µ":181,"¶":182,"·":183,"¸":184,"¹":185,"º":186,"»":187,"¼":188,"½":189,"¾":190,"¿":191,"À":192,"Á":193,"Â":194,"Ã":195,"Ä":196,"Å":197,"Æ":198,"Ç":199,"È":200,"É":201,"Ê":202,"Ë":203,"Ì":204,"Í":205,"Î":206,"Ï":207,"Ð":208,"Ñ":209,"Ò":210,"Ó":211,"Ô":212,"Õ":213,"Ö":214,"×":215,"Ø":216,"Ù":217,"Ú":218,"Û":219,"Ü":220,"Ý":221,"Þ":222,"ß":223,"à":224,"á":225,"â":226,"ã":227,"ä":228,"å":229,"æ":230,"ç":231,"è":232,"é":233,"ê":234,"ë":235,"ì":236,"í":237,"î":238,"ï":239,"ð":240,"ñ":241,"ò":242,"ó":243,"ô":244,"õ":245,"ö":246,"÷":247,"ø":248,"ù":249,"ú":250,"û":251,"ü":252,"ý":253,"þ":254,"ÿ":255})
  (defcap GOVERNANCE()
    (enforce-guard (keyset-ref-guard "free.admin-keyset"))
  )
  (defcap PRIVATE_RESERVE()
    true
  )
  (defcap END_ROUND()
    ;capability for ending current round
    (compose-capability (CREATE_ROUND))
    true
  )
  (defcap BURN()
    true
  )
  (defcap RETURN()
    true
  )
  (defcap CREATE_ROUND()
    true
  )
  (defcap VOTE(account:string amount:decimal)
    @managed amount VOTE_mgr
    (enforce-guard (at 'guard (coin.details account)))
    (compose-capability (ADD_VOTES))
    (compose-capability (MOVE_TO_PHASE_2))
    (compose-capability (END_ROUND))
    (compose-capability (RETURN))
    (compose-capability (BURN))
    true
  )
  (defun VOTE_mgr(managed:decimal requested:decimal)
    (let ((newbal (- managed requested)))
    (enforce (>= newbal 0.0)
      (format "TRANSFER exceeded for balance {}" [managed]))
    newbal)
  )
  (defcap ADD_VOTES()
    true
  )
  (defcap MOVE_TO_PHASE_2()
    true
  )

  (defun create-private-guard: guard()
    (require-capability (PRIVATE_RESERVE))
  )
  (defun create-reserve-guard:guard()
    (create-user-guard (create-private-guard))
  )

  (defschema state
    current-round:integer
  )
  (defschema investor
    name: string
    share: decimal
    accout: string
  )
  (defschema round-schema
    open-time: time
    close-time: time
    is-closed: bool
    filled-number: integer
    phase: string
    phase-1-voted-total: decimal
    voted-amount-list: [decimal]
    hash: string
  )
  (defschema votting-position-by-account
    total: decimal
    cnt: integer
    voted: bool
  )
  (defschema test-schema
    a: [integer]
  )
  (deftable state-table:{state})
  (deftable investor-table:{investor})
  (deftable round-table:{round-schema})
  (deftable votting-position-by-account-table:{votting-position-by-account})
  (deftable test-table:{test-schema})
  (defun init()
    (coin.create-account CONTRACT_ACCOUNT (create-reserve-guard))
    (insert state-table STATE_KEY {"current-round": -1})
    (with-capability (CREATE_ROUND) (create-new-round 0))
  )

  (defun enforce-current-round(round:integer)
    (let ((current-round (get-current-round)))
      (enforce (= round current-round) (format "{} is not current round!" [round]))
    )
  )
  (defun get-round-key (round:integer)
    (format "{}" [round])
  )
  (defun get-round-number-key (round: integer number: integer)
    (format "{}.{}" [round number])
  )
  (defun get-round-number-account-key (round: integer account:string number: integer)
    (format "{}.{}.{}" [round account number])
  )
  (defun vote(round:integer account:string number:integer amount:decimal want-to-end-current-round:bool)
    ;make sure round is current-round
    (enforce (> amount 0.0) "Amount must be positive!")
    (enforce-current-round round)
    (with-capability (VOTE account amount)
      (coin.transfer account CONTRACT_ACCOUNT amount)
      (let* ((round-number-account-key (get-round-number-account-key round account number))
            (round-key (get-round-key round))
            (round-state (read round-table round-key))
            (cur-phase (at "phase" round-state))
            (voted-amount-list (at "voted-amount-list" round-state))
            (voted-amount (at number voted-amount-list))
            )
        (with-default-read votting-position-by-account-table round-number-account-key {"total": 0.0, "cnt": 0, "voted": false} {"total":= cur-total, "cnt":= cur-cnt, "voted":= voted}
          (if (= voted true)
            (update votting-position-by-account-table round-number-account-key {"cnt": (+ cur-cnt 1), "total": (+ cur-total amount)})
            (insert votting-position-by-account-table round-number-account-key {"cnt": 1, "total": amount, "voted": true})))
        (add-votes round account number amount)
        (if (= true (can-move-to-phase-2 round)) (move-to-phase-2 round) true)
        (if (and (= cur-phase PHASE_TWO) (and want-to-end-current-round (can-end-current-round round account amount))) (end-current-round round) true)
      )
    )
  )

  (defun move-to-phase-2(round:integer)
    (require-capability (MOVE_TO_PHASE_2))
    (with-read round-table (get-round-key round) {"voted-amount-list":= voted-amount-list}
      (update round-table (get-round-key round) {"phase": PHASE_TWO, "phase-1-voted-total": (sum-list voted-amount-list)})
    )
  )
  (defun can-move-to-phase-2:bool(round:integer)
    (with-read round-table (get-round-key round) {"open-time":= open-time, "phase":= cur-phase}
      (and (> (diff-time (get-current-time) open-time) ROUND_DURATION) (= cur-phase PHASE_ONE))
    )
  )
  (defun can-end-current-round:bool(round:integer account:string amount:decimal)
    (with-read round-table (get-round-key round) {"hash":=cur-hash, "phase-1-voted-total":=phase-1-voted-total}
      (let*
        (
          (prev-block-hash (at "prev-block-hash" (chain-data)))
          (block-time (at "block-time" (chain-data)))
          (rd-number (rand block-time prev-block-hash cur-hash account))
        )
        (>= amount (* rd-number phase-1-voted-total)) ; rd-number <= amount / phase-1-voted-total>
      )
    )
  )

  (defun is-lucky:bool (round account)
    true
  )
  (defun end-current-round(round:integer)
    ;create new round, set current round by new round
    ;burn
    ;...

    ; (format "end round {}" [round])
    (require-capability (END_ROUND))
    (burn round)
    (update round-table (get-round-key round) {"close-time": (get-current-time), "is-closed": true})
    (create-new-round (+ round 1))
    (return-remain-fund round (+ round 1))
  )
  (defun get-current-time:time()
    (at "block-time" (chain-data))
  )

  (defun create-new-round(new-round:integer)
    (require-capability (CREATE_ROUND))
    (let (
        (current-round (get-current-round))
        (round-key (get-round-key new-round))
      )
      (enforce (= new-round (+ current-round 1)) (format "Can't create round {}. Previous round is {}" [new-round current-round]))
      (insert round-table round-key {
          "open-time": (get-current-time),
          "is-closed": false,
          "filled-number": 0,
          "close-time": (get-current-time),
          "voted-amount-list": (make-list 2 0.0),
          "phase-1-voted-total": 0.0,
          "phase": PHASE_ONE,
          "hash": (if (= new-round 0) (hash "initial hash") (at "hash" (round-details current-round)))
        }
      )
      (update state-table STATE_KEY {"current-round": new-round})
    )
  )
  (defun claim(account:string round:integer)
    ; make sure that each acount can clain at most 1 time
    (get-account-win-amount account round)
  )
  (defun get-account-win-amount(account:string round:integer)
    true
  )
  (defun house-withdraw(round:integer)
    true
  )
  (defun add-votes(round:integer account:string number:integer amount:decimal)
    (require-capability (ADD_VOTES))
    (with-read round-table (get-round-key round) {"filled-number":= filled-number, "voted-amount-list":= voted-amount-list, "hash":= cur-hash}
      (let*
        (
          (voted-amount (at number voted-amount-list))
          (updated-voted-amount-list (update-array-element voted-amount-list number (+ voted-amount amount)))
          (new-filled-number (if (= voted-amount 0.0) (+ filled-number 1) filled-number))
        )
        (update round-table (get-round-key round)
          {
            "filled-number": new-filled-number,
            "voted-amount-list": updated-voted-amount-list,
            "hash": (hash (concat [cur-hash (format "{}{}" [account amount])]))
          }
        )
      )
    )
  )
  (defun return-remain-fund(current-round:integer new-round:integer)
    (require-capability (RETURN))
    (let
      (
        (return-amount (get-return-amount current-round))
        (number (mod new-round 2))
      )
      (add-votes new-round CONTRACT_ACCOUNT number return-amount)
    )
  )
  (defun burn(round: integer)
    ;always burn at the end of each round, so this function can be private
    (require-capability (BURN))
    (let* ((burn-amount (get-burn-amount round)))
      (if (> burn-amount 0.0)
        [
          (install-capability (coin.TRANSFER CONTRACT_ACCOUNT BURN_ACCOUNT burn-amount))
          (with-capability (PRIVATE_RESERVE) (coin.transfer CONTRACT_ACCOUNT BURN_ACCOUNT burn-amount))
        ]
        true
      )
    )
  )
  (defun get-return-amount (round:integer)
    (let ((total-diff (get-total-diff round))) (* total-diff RETURN_RATE))
  )
  (defun get-burn-amount (round:integer)
    (let* ((total-diff (get-total-diff round))) (* total-diff BURN_RATE))
  )
  (defun get-house-ern-amount (round:integer)
    (let* ((total-diff (get-total-diff round))) (* total-diff HOUSE_ERN_RATE))
  )
  (defun get-total-diff(round:integer)
    (let* (
        (voted-amount-list (at "voted-amount-list" (round-details round)))
        (voted-total (sum-list voted-amount-list))
        (win-total (min-list voted-amount-list))
      )
      (- voted-total (* win-total 2))
    )
  )
  (defun round-details(round:integer)
    (read round-table (get-round-key round) ["open-time" "close-time" "filled-number" "is-closed" "voted-amount-list" "phase" "hash" "phase-1-voted-total"])
  )
  (defun get-current-round:integer()
    (with-default-read state-table STATE_KEY {"current-round": -1} {"current-round":=cur-round} cur-round )
  )

  (defun min(a:decimal b:decimal)
    (if (< a b) a b)
  )
  (defun min-list:decimal(a:[decimal])
    (enforce (> (length a) 0) "Empty list")
    (let ((first-item (at 0 a))) (fold (min) first-item a))
  )
  (defun test()
    (let ((a (enumerate 0 1000 1))) (insert test-table "test" {"a": a}))
  )
  (defun update-array-element(a:[decimal] index:integer newValue:decimal)
    (+ (take index a) (+ [newValue] (drop (+ index 1) a)))
  )
  (defun sum-list:decimal(a: [decimal])
    (fold (lambda (x:decimal y:decimal) (+ x y)) 0.0 a)
  )
  (defun lcg(init:integer a:[integer])
    "return (((init * M + a[0]) * M + a[1]) * M +.... + a[length-1] * M)) % m"
    (let
      (
        (f (lambda (t x) (mod (+ (* t MULTIPLYER) x) MODULES)))
      )
      (fold f init a)
    )
  )
  (defun at-default(key:string obj:object default-value)
    (if (contains key obj) (at key obj) default-value)
  )
  (defun string-to-ascii-codes:[integer](s:string)
    (map (lambda (x) (+ (at-default x CHAR_MAP 0) INCREMENT)) (str-to-list s))
  )
  (defun rand:decimal (current-time:time prev-block-hash:string cur-round-hash:string account:string)
    "return a random number in range [0, 1)"
    (let* (
      (_cur-round-hash (string-to-ascii-codes cur-round-hash))
      (_prev-block-hash (string-to-ascii-codes prev-block-hash))
      (_account (string-to-ascii-codes account))
      (_current-time (floor (* (diff-time current-time (time "1970-01-01T00:00:00Z")) 1000)))
      (rd_number (lcg (lcg (lcg (lcg 0 _cur-round-hash) [_current-time]) _account) _prev-block-hash))
    )
      (round (/ (* 1.0 rd_number) MODULES) 12)
    )
  )
)

(if (read-msg 'upgrade)
  ["upgrade"]
  [
    (create-table state-table)
    (create-table round-table)
    (create-table investor-table)
    (create-table votting-position-by-account-table)
    (create-table test-table)
    (init)
  ]
)