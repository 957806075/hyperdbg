PUBLIC AsmVmexitHandler

EXTERN VmxVmexitHandler:PROC
EXTERN VmxVmresume:PROC
EXTERN HvReturnStackPointerForVmxoff:PROC
EXTERN HvReturnInstructionPointerForVmxoff:PROC
EXTERN RtlCaptureContext:PROC
EXTERN RtlRestoreContext:PROC

include ksamd64.inc


.code _text

;------------------------------------------------------------------------
AsmRestoreContext PROC

        movaps  xmm0, CxXmm0[rcx]   ;
        movaps  xmm1, CxXmm1[rcx]   ;
        movaps  xmm2, CxXmm2[rcx]   ;
        movaps  xmm3, CxXmm3[rcx]   ;
        movaps  xmm4, CxXmm4[rcx]   ;
        movaps  xmm5, CxXmm5[rcx]   ;
        movaps  xmm6, CxXmm6[rcx]   ; Restore all XMM registers
        movaps  xmm7, CxXmm7[rcx]   ;
        movaps  xmm8, CxXmm8[rcx]   ;
        movaps  xmm9, CxXmm9[rcx]   ;
        movaps  xmm10, CxXmm10[rcx] ;
        movaps  xmm11, CxXmm11[rcx] ;
        movaps  xmm12, CxXmm12[rcx] ;
        movaps  xmm13, CxXmm13[rcx] ;
        movaps  xmm14, CxXmm14[rcx] ;
        movaps  xmm15, CxXmm15[rcx] ;
        ldmxcsr CxMxCsr[rcx]        ;

        mov     rax, CxRax[rcx]     ;
        mov     rdx, CxRdx[rcx]     ;
        mov     r8, CxR8[rcx]       ; Restore volatile registers
        mov     r9, CxR9[rcx]       ;
        mov     r10, CxR10[rcx]     ;
        mov     r11, CxR11[rcx]     ;

        mov     rbx, CxRbx[rcx]     ;
        mov     rsi, CxRsi[rcx]     ;
        mov     rdi, CxRdi[rcx]     ;
        mov     rbp, CxRbp[rcx]     ; Restore non volatile regsiters
        mov     r12, CxR12[rcx]     ;
        mov     r13, CxR13[rcx]     ;
        mov     r14, CxR14[rcx]     ;
        mov     r15, CxR15[rcx]     ;
        mov     rcx, CxRcx[rcx]     ; Restore Rcx
        ret


AsmRestoreContext ENDP
;------------------------------------------------------------------------

AsmVmexitHandler PROC
 ;   push 0  ; we might be in an unaligned stack state, so the memory before stack might cause 
            ; irql less or equal as it doesn't exist, so we just put some extra space avoid
            ; these kind of erros

    ;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SaveState:
    ; Save Flags
    push    rcx                 ; save the RCX register, which we spill below
    lea     rcx, [rsp+8h]       ; store the context in the stack, bias for
                                ; the return address and the push we just did.

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;;;;;;;;; Important note, we should make sure that rcx is aligned to 16 as ;;;;;;;;;
    ;;;;;;;;; RtlCaptureContext moves XMMs and these registers needs alignment ;;;;;;;;;
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    call    RtlCaptureContext   ; save the current register state.
    push    rcx                    ; Save rcx for future restore
    ;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

	sub	rsp, 28h		; Free some space for Shadow Section
	call	VmxVmexitHandler
	add	rsp, 28h		; Restore the state

    pop rcx     ; restore rcx for restore

	cmp	al, 1	; Check whether we have to turn off VMX or Not (the result is in RAX)
	je		AsmVmxoffHandler

    ;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    call AsmRestoreContext  ; rcx is pointer to restore point Context

	sub rsp, 0100h      ; to avoid error in future functions
	jmp VmxVmresume

AsmVmexitHandler ENDP

;------------------------------------------------------------------------

AsmVmxoffHandler PROC
    
    call AsmRestoreContext  ; rcx is pointer to restore point Context

    ; Actually, we can igonre most of these regs due to the volatility and non-volatility
    ; but let's not modify all the structure and just do what we have to do :)
    pushfq
    push r15
    push r14
    push r13
    push r12
    push r11
    push r10
    push r9
    push r8        
    push rdi
    push rsi
    push rbp
    push rbp	; rsp
    push rbx
    push rdx
    push rcx
    push rax	

    sub rsp, 020h       ; shadow space
    call HvReturnStackPointerForVmxoff
    add rsp, 020h       ; remove for shadow space

    mov [rsp+088h], rax  ; now, rax contains rsp

    sub rsp, 020h       ; shadow space
    call HvReturnInstructionPointerForVmxoff
    add rsp, 020h       ; remove for shadow space

    mov rdx, rsp        ; save current rsp

    mov rbx, [rsp+088h] ; read rsp again

    mov rsp, rbx

    push rax            ; push the return address as we changed the stack, we push
                        ; it to the new stack

    mov rsp, rdx        ; restore previous rsp
                        
    sub rbx,08h         ; we push sth, so we have to add (sub) +8 from previous stack
                        ; also rbx already contains the rsp
    mov [rsp+088h], rbx ; move the new pointer to the current stack

	RestoreState:

	pop rax
    pop rcx
    pop rdx
    pop rbx
    pop rbp		         ; rsp
    pop rbp
    pop rsi
    pop rdi 
    pop r8
    pop r9
    pop r10
    pop r11
    pop r12
    pop r13
    pop r14
    pop r15

    popfq

	pop		rsp     ; restore rsp

	ret             ; jump back to where we called Vmcall

AsmVmxoffHandler ENDP

;------------------------------------------------------------------------

END
