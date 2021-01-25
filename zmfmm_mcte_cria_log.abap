FUNCTION zmfmm_mcte_cria_log.
*"----------------------------------------------------------------------
*"*"Interface local:
*"  IMPORTING
*"     REFERENCE(I_MULTIID) TYPE  ZEMM_MULTIID
*"     REFERENCE(I_STATUS_PROC) TYPE  ZEMM_STATUS_PROC
*"     REFERENCE(I_BAPIRET2) LIKE  BAPIRET2 STRUCTURE  BAPIRET2
*"       OPTIONAL
*"     REFERENCE(I_TIPO) TYPE  BAPI_MTYPE OPTIONAL
*"     REFERENCE(I_TEXTO) TYPE  BAPI_MSG OPTIONAL
*"     REFERENCE(I_MESSAGE_V1) TYPE  SYMSGV OPTIONAL
*"     REFERENCE(I_MESSAGE_V2) TYPE  SYMSGV OPTIONAL
*"     REFERENCE(I_MESSAGE_V3) TYPE  SYMSGV OPTIONAL
*"     REFERENCE(I_MESSAGE_V4) TYPE  SYMSGV OPTIONAL
*"  EXCEPTIONS
*"      MULTI_ID_N_ENCONTRADO
*"      TIPO_TEXTO_N_PREENCHIDOS
*"----------------------------------------------------------------------

  DATA: wl_ztmm_028_new TYPE ztmm_028.

  DATA: tl_callst TYPE sys_callst.

  SELECT SINGLE multiid
    FROM ztmm_027
    INTO @DATA(wl_ztmm_027)
    WHERE multiid EQ @i_multiid.

  IF wl_ztmm_027 IS INITIAL.
    RAISE multi_id_n_encontrado.
  ENDIF.

  SELECT multiid, status_proc, log_id
    FROM ztmm_028
    INTO TABLE @DATA(tl_ztmm_028)
    WHERE multiid EQ @i_multiid.

  IF i_bapiret2 IS NOT INITIAL.

    MOVE: i_bapiret2-type       TO wl_ztmm_028_new-tipo,
          i_bapiret2-message    TO wl_ztmm_028_new-texto,
          i_bapiret2-message_v1 TO wl_ztmm_028_new-message_v1,
          i_bapiret2-message_v2 TO wl_ztmm_028_new-message_v2,
          i_bapiret2-message_v3 TO wl_ztmm_028_new-message_v3,
          i_bapiret2-message_v4 TO wl_ztmm_028_new-message_v4.

  ELSE.

    MOVE: i_tipo       TO wl_ztmm_028_new-tipo,
          i_texto      TO wl_ztmm_028_new-texto,
          i_message_v1 TO wl_ztmm_028_new-message_v1,
          i_message_v2 TO wl_ztmm_028_new-message_v2,
          i_message_v3 TO wl_ztmm_028_new-message_v3,
          i_message_v4 TO wl_ztmm_028_new-message_v4.

  ENDIF.

  IF wl_ztmm_028_new-tipo IS INITIAL OR wl_ztmm_028_new-texto IS INITIAL.
    RAISE tipo_texto_n_preenchidos.
  ENDIF.

  IF tl_ztmm_028[] IS NOT INITIAL.

    SORT tl_ztmm_028 BY log_id DESCENDING.

    DATA(wl_ztmm_028) = tl_ztmm_028[ 1 ].

    wl_ztmm_028_new-log_id = wl_ztmm_028-log_id + 1.

  ELSE.

    wl_ztmm_028_new-log_id = 1.

  ENDIF.
*
*ORIGEM_EXEC
  CALL FUNCTION 'SYSTEM_CALLSTACK'
    EXPORTING
      max_level    = 2
    IMPORTING
      et_callstack = tl_callst.

  IF tl_callst[] IS NOT INITIAL.
    wl_ztmm_028_new-origem_exec = tl_callst[ 2 ]-progname.
  ENDIF.

  CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
    EXPORTING
      input  = wl_ztmm_028_new-log_id
    IMPORTING
      output = wl_ztmm_028_new-log_id.

  MOVE: i_multiid     TO wl_ztmm_028_new-multiid,
        i_status_proc TO wl_ztmm_028_new-status_proc,
        sy-datum      TO wl_ztmm_028_new-data_log,
        sy-uzeit      TO wl_ztmm_028_new-hora_log,
        sy-uname      TO wl_ztmm_028_new-username.

  MODIFY ztmm_028 FROM @wl_ztmm_028_new.

ENDFUNCTION.
