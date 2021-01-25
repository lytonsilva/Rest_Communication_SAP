FUNCTION zmfmm_mcte_prev_pag_post .
*"----------------------------------------------------------------------
*"*"Interface local:
*"  IMPORTING
*"     REFERENCE(I_POST) TYPE  ZSMM_013
*"  EXPORTING
*"     REFERENCE(E_HTTP_STATUS) TYPE  STRING
*"     REFERENCE(E_REASON) TYPE  STRING
*"     REFERENCE(E_ERRO) TYPE  CHAR1
*"  EXCEPTIONS
*"      CONNECTION_FAILED
*"----------------------------------------------------------------------

* Objetos Locais
  DATA: ol_http_client     TYPE REF TO if_http_client,
        ol_rest_client     TYPE REF TO cl_rest_http_client,
        ol_json            TYPE REF TO cl_clb_parse_json,
        ol_response        TYPE REF TO if_rest_entity,
        ol_request         TYPE REF TO if_rest_entity,
        ol_sql             TYPE REF TO cx_sy_open_sql_db,
        ol_oref            TYPE REF TO cx_root,
        ol_json_serializer TYPE REF TO cl_trex_json_serializer.

* Variáveis Locais
  DATA: vl_url                    TYPE string, "VALUE '/grb/sb/api/cte/previsaoPagamento',
        vl_http_status            TYPE string,
        vl_body                   TYPE string,
        vl_service                TYPE string, "VALUE 'https://hapi.grupoboticario.com.br',
        vl_json_req               TYPE string,
        vl_service_return         TYPE string,
        vl_response               TYPE string,
        vl_token                  TYPE string,
        vl_sysid                  TYPE sy-sysid,
        vl_client_id              TYPE string,
        vl_client_secret          TYPE string,
        vl_obs                    TYPE zsmm_014-observacao,
        vl_service_return_erro    TYPE zsmm_010,
        vl_service_return_sucesso TYPE zsmm_011,
        vl_status_proc            TYPE zemm_status_proc,
        vl_mens                   TYPE bapi_msg.

  DATA: wl_json_req TYPE tp_zsmm_prev_pag,
        wl_ztmm_032 TYPE ztmm_032,
        wl_ztmm_034 TYPE ztmm_034,
        wl_prev_pag TYPE zsmm_014.

* Constantes Locais
  CONSTANTS:
      co_timeout           TYPE string VALUE ' (Timeout)'.

  SELECT SINGLE *
    FROM ztmm_032
    INTO wl_ztmm_032
    WHERE integracao EQ 'PREV_PAG'.

  SELECT SINGLE *
    FROM ztmm_034
    INTO wl_ztmm_034
    WHERE sysid EQ sy-sysid.

  SELECT SINGLE multiid, status_proc
    FROM ztmm_027
    INTO @DATA(wl_ztmm_027)
    WHERE multiid EQ @i_post-multiid.

  MOVE: i_post-multiid           TO wl_prev_pag-protocolocte,
        i_post-data              TO wl_prev_pag-data,
        i_post-observacao        TO wl_prev_pag-observacao.

  IF wl_ztmm_032-destination IS NOT INITIAL.

* SM59 Configuração
    cl_http_client=>create_by_destination(
     EXPORTING
       destination              = wl_ztmm_032-destination  " Logical destination (specified in function call)
     IMPORTING
       client                   = ol_http_client           " HTTP Client Abstraction
     EXCEPTIONS
       argument_not_found       = 1
       destination_not_found    = 2
       destination_no_authority = 3
       plugin_not_active        = 4
       internal_error           = 5
       OTHERS                   = 6 ).

  ELSE.

    MOVE: wl_ztmm_032-service TO vl_service.
    MOVE: wl_ztmm_032-url TO vl_url.

    CALL METHOD cl_http_client=>create_by_url(
      EXPORTING
        url                = vl_service
      IMPORTING
        client             = ol_http_client               " HTTP Client Abstraction
      EXCEPTIONS
        argument_not_found = 1
        plugin_not_active  = 2
        internal_error     = 3
        OTHERS             = 4 ).

  ENDIF.

  IF ol_http_client IS NOT INITIAL AND wl_ztmm_032-url IS NOT INITIAL
     AND wl_ztmm_034 IS NOT INITIAL AND wl_ztmm_027-multiid IS NOT INITIAL.

* HTTP basic authenication
    ol_http_client->propertytype_logon_popup = if_http_client=>co_disabled.

    CREATE OBJECT ol_rest_client
      EXPORTING
        io_http_client = ol_http_client.

    ol_http_client->request->set_version( if_http_request=>co_protocol_version_1_0 ).

    IF ol_http_client IS BOUND AND ol_rest_client IS BOUND.

* Campos de cabeçalho
      MOVE: wl_ztmm_034-client_id     TO vl_client_id,
            wl_ztmm_034-client_secret TO vl_client_secret.

      CALL METHOD ol_http_client->request->set_header_field
        EXPORTING
          name  = 'X-IBM-Client-Id'
          value = vl_client_id.

      CALL METHOD ol_http_client->request->set_header_field
        EXPORTING
          name  = 'X-IBM-Client-secret'
          value = vl_client_secret.

      CALL METHOD ol_http_client->request->set_header_field
        EXPORTING
          name  = 'unidadeNegocio'
          value = 'GB'.

      CALL METHOD ol_http_client->request->set_header_field
        EXPORTING
          name  = 'content-type'
          value = 'application/json'.

      cl_http_utility=>set_request_uri(
        EXPORTING
          request = ol_http_client->request    " HTTP Framework (iHTTP) HTTP Request
          uri     = vl_url                     " URI String (in the Form of /path?query-string)

      ).


* ABAP to JSON

      MOVE-CORRESPONDING wl_prev_pag TO wl_json_req.

      CALL FUNCTION 'CONVERT_DATE_TO_EXTERNAL'
        EXPORTING
          date_internal            = wl_prev_pag-data
        IMPORTING
          date_external            = wl_json_req-data
        EXCEPTIONS
          date_internal_is_invalid = 1
          OTHERS                   = 2.

      REPLACE ALL OCCURRENCES OF '.' IN wl_json_req-data WITH '/'.

* Converted JSON should look like this
      vl_body                  = /ui2/cl_json=>serialize( data = wl_json_req ).

* Set Payload or body ( JSON or XML)
      ol_request = ol_rest_client->if_rest_client~create_request_entity( ).

      TRANSLATE vl_body TO LOWER CASE.

      MOVE: wl_json_req-observacao TO vl_obs.
      TRANSLATE vl_obs TO LOWER CASE.

      REPLACE ALL OCCURRENCES OF 'cte' IN vl_body WITH 'CTE'.
      REPLACE ALL OCCURRENCES OF vl_obs IN vl_body WITH wl_json_req-observacao.

      ol_request->set_string_data( vl_body ).

* POST
      TRY.
          ol_rest_client->if_rest_resource~post( ol_request ).

        CATCH  cx_rest_client_exception INTO ol_oref.

          ol_response     = ol_rest_client->if_rest_client~get_response_entity( ).
          e_http_status   = ol_response->get_header_field( '~status_code' ).
          e_reason        = ol_response->get_header_field( '~status_reason' ).
          vl_response     = ol_response->get_string_data( ).

          IF e_reason IS NOT INITIAL.

            TRY.
                IF vl_response IS NOT INITIAL.
                  /ui2/cl_json=>deserialize( EXPORTING json = vl_response CHANGING data = vl_service_return_erro ).
                ENDIF.
              CATCH cx_root INTO ol_oref .
            ENDTRY.

            MESSAGE e003(zmm_mcte) INTO vl_mens.
            e_erro = 'X'.
            MOVE: '07' TO vl_status_proc.

            "Falha na Interface - Dados Não Enviados
            CALL FUNCTION 'ZMFMM_MCTE_CRIA_LOG'
              EXPORTING
                i_multiid                = wl_prev_pag-protocolocte
                i_status_proc            = vl_status_proc
                i_tipo                   = 'E'
                i_texto                  = vl_mens
              EXCEPTIONS
                multi_id_n_encontrado    = 1
                tipo_texto_n_preenchidos = 2
                OTHERS                   = 3.

          ENDIF.

          MESSAGE e000(zmm) WITH 'Sistema Multi-cte está inoperante'
            RAISING connection_failed. "" RAMONL/ COINOV

      ENDTRY.

* Response

      ol_response    = ol_rest_client->if_rest_client~get_response_entity( ).
      e_http_status  = ol_response->get_header_field( '~status_code' ).
      e_reason       = ol_response->get_header_field( '~status_reason' ).
      vl_response    = ol_response->get_string_data( ).

      IF e_http_status = '201'.

        TRY.
            IF vl_response IS NOT INITIAL.
              /ui2/cl_json=>deserialize( EXPORTING json = vl_response CHANGING data = vl_service_return_sucesso ).
            ENDIF.
          CATCH cx_root INTO ol_oref .
        ENDTRY.

        MOVE: '05' TO vl_status_proc.

        CALL FUNCTION 'ZMFMM_MCTE_CRIA_LOG'
          EXPORTING
            i_multiid                = wl_prev_pag-protocolocte
            i_status_proc            = vl_status_proc
            i_tipo                   = 'S'
            i_texto                  = vl_service_return_sucesso-mensagem
          EXCEPTIONS
            multi_id_n_encontrado    = 1
            tipo_texto_n_preenchidos = 2
            OTHERS                   = 3.

      ELSE.

        TRY.
            IF vl_response IS NOT INITIAL.
              /ui2/cl_json=>deserialize( EXPORTING json = vl_response CHANGING data = vl_service_return_erro ).
            ENDIF.
          CATCH cx_root INTO ol_oref .
        ENDTRY.

        MOVE: '07' TO vl_status_proc.
        e_erro = 'X'.

        CALL FUNCTION 'ZMFMM_MCTE_CRIA_LOG'
          EXPORTING
            i_multiid                = wl_prev_pag-protocolocte
            i_status_proc            = vl_status_proc
            i_tipo                   = 'E'
            i_texto                  = vl_service_return_erro-moreinformation
            i_message_v1             = vl_service_return_erro-httpcode
            i_message_v2             = vl_service_return_erro-httpmessage
            i_message_v3             = vl_service_return_erro-uuid
            i_message_v4             = vl_service_return_erro-errorcode
          EXCEPTIONS
            multi_id_n_encontrado    = 1
            tipo_texto_n_preenchidos = 2
            OTHERS                   = 3.

      ENDIF.

    ENDIF.
  ELSE.
    RAISE no_data.
  ENDIF.
ENDFUNCTION.
