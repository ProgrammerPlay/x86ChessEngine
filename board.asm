global aiMove
extern	printf

section .data
	printH		db	"%016llx",10,0	;print in hex 64bit
	printD		db	"%d",10,0	;print normal decimal
	printHere	db	"Here",10,0	;test msg

	aiDepth		db	2	;depth for negaMax tree
	aiPlayer	db 	1	;if ai is black/white default black

	blackBoard 	dq 	0x0	;used to store black pieces when calc
	whiteBoard 	dq 	0x0	;used to store white pieces when calc

					;bitboards for white
	whitePawns 	dq 	0xff00
	whiteBishops 	dq	0x24
	whiteKnights 	dq 	0x42
	whiteCastles 	dq 	0x81
	whiteQueens 	dq 	0x8
	whiteKing 	dq 	0x10

							;bitboards for black
	blackPawns  	dq 	0xff000000000000
	blackBishops 	dq 	0x2400000000000000
	blackKnights 	dq 	0x4200000000000000
	blackCastles	dq	0x8100000000000000
	blackQueens 	dq 	0x800000000000000
	blackKing    	dq	0x1000000000000000

section .bss
	resb 1024
section .text
aiMove:
	;call fillWhiteBoard

	;mov rax, [whitePawns]
	;call calcMove

	;testing ai
	mov ch, [aiPlayer]					;which player is ai
	mov cl, [aiDepth]					;depth for negamax to check moves
	call ai
	ret

;--------------------------------------
;NegaMax Procedure
;This is the backbone of our AI
;analyzes all best moves to "AIdepth"
;for each player choces best for itself
;---------
;Expects depth in cl
;--------------------------------------
;Upper negaMax gets score for every current move on one side
ai:
	xor rax, rax	;what piece's move we are on
	xor rcx, rcx	;hold higest move score
	call getMoves
loopAI:
	call pushGame	;save current game state
	sub rsp, 8*12	
	sub rsp, 8*12	;align sp to top of move to pop
	call popGame	;pop the game to that move from getMoves
	push rax
	inc rsp
	call depthNega	;get depth score for that move
	cmp rax, rcx
	jg continueLoopAI
	mov rcx, rax	;store greater score
continueLoopAI:
	dec rsp
	pop rax
	add rsp, 8*12	;align sp to top of that move
	call popGame	;undo moves
	add rsp, 8*12
	dec rax		;dec loop
	cmp rax, 0	
	je doneAI
doneAI:
	ret

;search deep to find the best move
depthNega:
	cmp cl, 0
	je doneNega	;reached bottom of our search tree
	dec cl		;dec tree search depth
	mov rax, -300	;worse case score
			;check moves for all unique piece types on given side
	mov dl, 0	
allMoves:		;loop over all players posible moves
			;do moves				
	push rax	;push score
	call depthNega	;recurse
	pop rbx		;pop last max
			;restore all bitboards
			;undo move
	imul rbx, -1	;negate returned value from eval 
	cmp rax,rbx	;is new score (rbx) higher?
	jg swapMaxScore
swapMaxScore:
	mov rax, rbx	;swap max with score
doneNega:
	;call eval		;get an evaluation
	ret			;done


;-------------------------------
;Push all bitboard into stack
;Negamax uses this to save game state
;as it checks all moves
;For every push we need to do a pop
;-------------------------------
pushGame:			;push all bitboards down into stack
	push qWord [whitePawns]
	push qWord [whiteBishops]
	push qWord [whiteKnights]
	push qWord [whiteCastles]
	push qWord [whiteQueens]
	push qWord [whiteKing]


	push qWord [blackPawns]
	push qWord [blackBishops]
	push qWord [blackKnights]
	push qWord [blackCastles]
	push qWord [blackQueens]
	push qWord [blackKing]

	;jmp afterGamePush
	add rsp, 8 * 12
	ret

;-------------------------------
;Pop back all bitboards from stack
;-------------------------------
popGame:
	pop qWord [blackKing]
	pop qWord [blackQueens]
	pop qWord [blackCastles]
	pop qWord [blackKnights]
	pop qWord [blackBishops]
	pop qWord [blackPawns]

	pop qWord [whiteKing]
	pop qWord [whiteQueens]
	pop qWord [whiteCastles]
	pop qWord [whiteKnights]
	pop qWord [whiteBishops]
	pop qWord [whitePawns]

	;jmp afterGamePop
	sub rsp, 8*12
	ret

;-------------------------------
;Evaluates a players side against the oposite
;Expects address of pawn's bitboard of player to eval in rbx!
;Sned player to evar in rcx, 1 = white | -1 = black
;------------------
;values:
;pawns = 1
;bishops & knights = 3
;rooks = 5
;queen = 9
;king = 200
;-------------------------------
eval:
	push rcx
	popcnt rax, [rbx]		;count how many bits are on
	popcnt rcx, [rbx+8]		;bishop bitBoard
	imul rcx, 3			;bishop weight
	add rax, rcx			;add it to values
	popcnt rcx, [rbx+16]		;kights to bitboard
	imul rcx, 3			;knight weight
	add rax, rcx
	popcnt rcx, [rbx+24]		;rooks
	imul rcx, 5			;rook value
	add rax, rcx
	popcnt rcx, [rbx+32]		;queens
	imul rcx, 9			;queen value
	add rax, rcx
	popcnt rcx, [rbx+40]		;still have a king?
	imul rcx, 200			;king's value
	add rax, rcx
	pop rcx

	push rdx
	xor edx, edx
	mov dl, ch			;what player side
	imul rax, rdx			;mul by player color
	pop rdx
	ret							;end of procedure

;-------------------------------
;Fill board with all black positions
;-------------------------------
fillBlackBoard:
	push rax
	push rcx
	push rbx
	mov rcx, 6
	mov rbx, blackPawns			;start of black bitboards address
	xor rax, rax
loopfillBlackBoard:				;loop through the bitboards
	or rax, [rbx + rcx * 8]
	dec rcx
	cmp rcx, 0
	jne loopfillBlackBoard
	mov [blackBoard], rax
	pop rbx
	pop rcx
	pop rax
	ret

;-------------------------------
;Fill board with all white positions
;-------------------------------
fillWhiteBoard:					;same as fillBlackBoard but white
	push rax
	push rcx
	push rbx
	mov rcx, 6
	mov rbx, whitePawns
	xor rax, rax
loopfillWhiteBoard:
	or rax, [rbx + rcx * 8]
	dec rcx
	cmp rcx, 0
	jne loopfillWhiteBoard
	mov [whiteBoard], rax
	pop rbx
	pop rcx
	pop rax
	ret

;--------------------------------
;Push all posible moves into stack
;also place num of posible moves in rax
;--------------------------------
getMoves:
	call pawnMoves	;figure out pawn moves
	ret


;--------------------------------
;Pawn movement AI, send it pawn
; rcx = 1 white	player
; rcx = -1 black player
;--------------------------------
pawnMoves:
	;cmp rcx, 1		;if dd then white
	;jne blackPawn

	mov rdx, [whitePawns]
	popcnt rcx, [whitePawns]
	xor rax, rax		;loop counter
whitePawn:			;moves for eachPawn 
	push rcx		;push num of white pawn 
	push rax
	push rdx		;save original pawns place
	shl rdx, 0x8		;check one move forward

	call fillWhiteBoard
	mov rax, [whiteBoard]
	not rax
	and rdx, rax
	pop rax			;get original pawn pos back in rax

	cmp rdx, 0		;if not posible move we are done
	je donePawnMove

	push qWord [whitePawns] ;save the current pawns
	xor [whitePawns], rax	;eliminate the pawn to move
	xor [whitePawns], rcx	;make the pawnMove
	call pushGame		;same the game move for the ai
	pop qWord [whitePawns]  ;retore them

donePawnMove:
	pop rax			;pop loop counter
	pop rcx			;pop num of pawns

	inc rax
	cmp rax, rcx
	jle whitePawn
	ret			;end pawn move
