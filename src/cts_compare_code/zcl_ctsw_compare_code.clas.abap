CLASS zcl_ctsw_compare_code DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    TYPES:
      BEGIN OF ty_file_diff,
        path       TYPE string,
        filename   TYPE string,
        lstate     TYPE char1,
        rstate     TYPE char1,
        fstate     TYPE char1, " FILE state - Abstraction for shorter ifs
        o_diff     TYPE REF TO zcl_ctsw_diff,
        changed_by TYPE xubname,
        type       TYPE string,
      END OF ty_file_diff .
    TYPES:
      tt_file_diff TYPE STANDARD TABLE OF ty_file_diff .

    CONSTANTS:
      BEGIN OF c_fstate,
        local  TYPE char1 VALUE 'L',
        remote TYPE char1 VALUE 'R',
        both   TYPE char1 VALUE 'B',
      END OF c_fstate .

    METHODS constructor .
    CLASS-METHODS render_diff_public
      IMPORTING
        !is_diff       TYPE zcl_ctsw_compare_code=>ty_file_diff
      RETURNING
        VALUE(ro_html) TYPE REF TO zcl_ctsw_html .

  PROTECTED SECTION.






  PRIVATE SECTION.
    TYPES: ty_patch_action TYPE string.

    CONSTANTS: BEGIN OF c_actions,
                 stage          TYPE string VALUE 'patch_stage',
                 toggle_unified TYPE string VALUE 'toggle_unified',
               END OF c_actions,
               BEGIN OF c_patch_action,
                 add    TYPE ty_patch_action VALUE 'add',
                 remove TYPE ty_patch_action VALUE 'remove',
               END OF c_patch_action.

    DATA: mt_delayed_lines TYPE zif_cts_definitions=>ty_diffs_tt,
          mv_unified       TYPE abap_bool VALUE abap_true,
          mv_patch_mode    TYPE abap_bool,
          mv_section_count TYPE i.

    METHODS render_diff
      IMPORTING is_diff        TYPE ty_file_diff
      RETURNING VALUE(ro_html) TYPE REF TO zcl_ctsw_html.
    METHODS render_diff_head
      IMPORTING is_diff        TYPE ty_file_diff
      RETURNING VALUE(ro_html) TYPE REF TO zcl_ctsw_html.
    METHODS render_table_head
      IMPORTING is_diff        TYPE ty_file_diff
      RETURNING VALUE(ro_html) TYPE REF TO zcl_ctsw_html.
    METHODS render_lines
      IMPORTING is_diff        TYPE ty_file_diff
      RETURNING VALUE(ro_html) TYPE REF TO zcl_ctsw_html.
    METHODS render_beacon
      IMPORTING is_diff_line   TYPE zif_cts_definitions=>ty_diff
                is_diff        TYPE ty_file_diff
      RETURNING VALUE(ro_html) TYPE REF TO zcl_ctsw_html.
    METHODS render_line_split
      IMPORTING is_diff_line   TYPE zif_cts_definitions=>ty_diff
                iv_filename    TYPE string
                iv_fstate      TYPE char1
                iv_index       TYPE sy-tabix
      RETURNING VALUE(ro_html) TYPE REF TO zcl_ctsw_html.
    METHODS render_line_unified
      IMPORTING is_diff_line   TYPE zif_cts_definitions=>ty_diff OPTIONAL
      RETURNING VALUE(ro_html) TYPE REF TO zcl_ctsw_html.










    CLASS-METHODS render_item_state
      IMPORTING
        !iv_lstate     TYPE char1
        !iv_rstate     TYPE char1
      RETURNING
        VALUE(rv_html) TYPE string .

ENDCLASS.



CLASS zcl_ctsw_compare_code IMPLEMENTATION.

















  METHOD constructor.
*-----------------------------------------------------------------------
* Constructor
*-----------------------------------------------------------------------
* Change     Developer    Date       Description
* CHGxxxxxxx ADKRA\774888 18.10.2019 Method created
*-----------------------------------------------------------------------

    super->constructor( ).

  ENDMETHOD.


  METHOD render_beacon.

    DATA: lv_beacon  TYPE string,
          lt_beacons TYPE zif_cts_definitions=>ty_string_tt.

    CREATE OBJECT ro_html.

    mv_section_count = mv_section_count + 1.

    IF is_diff_line-beacon > 0.
      lt_beacons = is_diff-o_diff->get_beacons( ).
      READ TABLE lt_beacons INTO lv_beacon INDEX is_diff_line-beacon.
    ELSE.
      lv_beacon = '---'.
    ENDIF.

    ro_html->add( '<thead class="nav_line">' ).
    ro_html->add( '<tr>' ).

    IF mv_patch_mode = abap_true.

      ro_html->add( |<th class="patch">| ).
      ro_html->add_checkbox( iv_id = |patch_section_{ is_diff-filename }_{ mv_section_count }| ).
      ro_html->add( '</th>' ).

    ELSE.
      ro_html->add( '<th class="num"></th>' ).
    ENDIF.
    IF mv_unified = abap_true.
      ro_html->add( '<th class="num"></th>' ).
      ro_html->add( |<th>@@ { is_diff_line-new_num } @@ { lv_beacon }</th>| ).
    ELSE.
      ro_html->add( |<th colspan="3">@@ { is_diff_line-new_num } @@ { lv_beacon }</th>| ).
    ENDIF.

    ro_html->add( '</tr>' ).
    ro_html->add( '</thead>' ).

  ENDMETHOD.


  METHOD render_diff.

    CREATE OBJECT ro_html.

    ro_html->add( |<div class="diff" data-type="{ is_diff-type
      }" data-changed-by="{ is_diff-changed_by
      }" data-file="{ is_diff-path && is_diff-filename }">| ). "#EC NOTEXT
    ro_html->add( render_diff_head( is_diff ) ).

    " Content
    IF is_diff-type <> 'binary'.
      ro_html->add( '<div class="diff_content">' ).         "#EC NOTEXT
      ro_html->add( |<table class="diff_tab syntax-hl" id={ is_diff-filename }>| ). "#EC NOTEXT
      ro_html->add( render_table_head( is_diff ) ).
      ro_html->add( render_lines( is_diff ) ).
      ro_html->add( '</table>' ).                           "#EC NOTEXT
    ELSE.
      ro_html->add( '<div class="diff_content paddings center grey">' ). "#EC NOTEXT
      ro_html->add( 'The content seems to be binary.' ).    "#EC NOTEXT
      ro_html->add( 'Cannot display as diff.' ).            "#EC NOTEXT
    ENDIF.
    ro_html->add( '</div>' ).                               "#EC NOTEXT

    ro_html->add( '</div>' ).                               "#EC NOTEXT

  ENDMETHOD.


  METHOD render_diff_head.

    DATA: ls_stats TYPE zif_cts_definitions=>ty_count.

    CREATE OBJECT ro_html.

    ro_html->add( '<div class="diff_head">' ).              "#EC NOTEXT

    IF is_diff-type <> 'binary'.
      ls_stats = is_diff-o_diff->stats( ).
      IF is_diff-fstate = c_fstate-both. " Merge stats into 'update' if both were changed
        ls_stats-update = ls_stats-update + ls_stats-insert + ls_stats-delete.
        CLEAR: ls_stats-insert, ls_stats-delete.
      ENDIF.

      ro_html->add( |<span class="diff_banner diff_ins">+ { ls_stats-insert }</span>| ).
      ro_html->add( |<span class="diff_banner diff_del">- { ls_stats-delete }</span>| ).
      ro_html->add( |<span class="diff_banner diff_upd">~ { ls_stats-update }</span>| ).
    ENDIF.

    ro_html->add( |<span class="diff_name">{ is_diff-path }{ is_diff-filename }</span>| ). "#EC NOTEXT
    ro_html->add( render_item_state(
      iv_lstate = is_diff-lstate
      iv_rstate = is_diff-rstate ) ).

    IF is_diff-fstate = c_fstate-both AND mv_unified = abap_true.
      ro_html->add( '<span class="attention pad-sides">Attention: Unified mode'
                 && ' highlighting for MM assumes local file is newer ! </span>' ). "#EC NOTEXT
    ENDIF.

    ro_html->add( |<span class="diff_changed_by">last change by: <span class="user">{
      is_diff-changed_by }</span></span>| ).

    ro_html->add( '</div>' ).                               "#EC NOTEXT

  ENDMETHOD.


  METHOD render_diff_public.
    DATA(lo_diff) = NEW zcl_ctsw_compare_code( ).
    lo_diff->mv_unified = abap_false.

    ro_html = lo_diff->render_diff( is_diff ).

  ENDMETHOD.


  METHOD render_lines.

    DATA: lt_diffs       TYPE zif_cts_definitions=>ty_diffs_tt,
          lv_insert_nav  TYPE abap_bool,
          lv_tabix       TYPE syst-tabix.

    FIELD-SYMBOLS <ls_diff>  LIKE LINE OF lt_diffs.

    CREATE OBJECT ro_html.

    lt_diffs = is_diff-o_diff->get( ).

    LOOP AT lt_diffs ASSIGNING <ls_diff>.

      lv_tabix = sy-tabix.

      IF <ls_diff>-short = abap_false.
        lv_insert_nav = abap_true.
        CONTINUE.
      ENDIF.

      IF lv_insert_nav = abap_true. " Insert separator line with navigation
        ro_html->add( render_beacon( is_diff_line = <ls_diff> is_diff = is_diff ) ).
        lv_insert_nav = abap_false.
      ENDIF.

      <ls_diff>-new = escape( val = <ls_diff>-new format = cl_abap_format=>e_html_attr ).
      <ls_diff>-old = escape( val = <ls_diff>-old format = cl_abap_format=>e_html_attr ).

      CONDENSE <ls_diff>-new_num. "get rid of leading spaces
      CONDENSE <ls_diff>-old_num.

      IF mv_unified = abap_true.
        ro_html->add( render_line_unified( is_diff_line = <ls_diff> ) ).
      ELSE.
        ro_html->add( render_line_split( is_diff_line = <ls_diff>
                                         iv_filename  = is_diff-filename
                                         iv_fstate    = is_diff-fstate
                                         iv_index     = lv_tabix ) ).
      ENDIF.

    ENDLOOP.

    IF mv_unified = abap_true.
      ro_html->add( render_line_unified( ) ). " Release delayed lines
    ENDIF.

  ENDMETHOD.


  METHOD render_line_split.

    DATA: lv_new                 TYPE string,
          lv_old                 TYPE string,
          lv_mark                TYPE string,
          lv_bg                  TYPE string,
          lv_patch_line_possible TYPE abap_bool.

    CREATE OBJECT ro_html.

    " New line
    lv_mark = ` `.
    IF is_diff_line-result IS NOT INITIAL.
      IF iv_fstate = c_fstate-both OR is_diff_line-result = zif_cts_definitions=>c_diff-update.
        lv_bg = ' diff_upd'.
        lv_mark = `~`.
      ELSEIF is_diff_line-result = zif_cts_definitions=>c_diff-insert.
        lv_bg = ' diff_ins'.
        lv_mark = `+`.
      ENDIF.
    ENDIF.
    lv_new = |<td class="num" line-num="{ is_diff_line-new_num }"></td>|
          && |<td class="code{ lv_bg }">{ lv_mark }{ is_diff_line-new }</td>|.

    IF lv_mark <> ` `.
      lv_patch_line_possible = abap_true.
    ENDIF.

    " Old line
    CLEAR lv_bg.
    lv_mark = ` `.
    IF is_diff_line-result IS NOT INITIAL.
      IF iv_fstate = c_fstate-both OR is_diff_line-result = zif_cts_definitions=>c_diff-update.
        lv_bg = ' diff_upd'.
        lv_mark = `~`.
      ELSEIF is_diff_line-result = zif_cts_definitions=>c_diff-delete.
        lv_bg = ' diff_del'.
        lv_mark = `-`.
      ENDIF.
    ENDIF.
    lv_old = |<td class="num" line-num="{ is_diff_line-old_num }"></td>|
          && |<td class="code{ lv_bg }">{ lv_mark }{ is_diff_line-old }</td>|.

    IF lv_mark <> ` `.
      lv_patch_line_possible = abap_true.
    ENDIF.

    " render line, inverse sides if remote is newer
    ro_html->add( '<tr>' ).                                 "#EC NOTEXT

    IF iv_fstate = c_fstate-remote. " Remote file leading changes
      ro_html->add( lv_old ). " local
      ro_html->add( lv_new ). " remote
    ELSE.             " Local leading changes or both were modified
      ro_html->add( lv_new ). " local
      ro_html->add( lv_old ). " remote
    ENDIF.

    ro_html->add( '</tr>' ).                                "#EC NOTEXT

  ENDMETHOD.


  METHOD render_line_unified.

    FIELD-SYMBOLS <ls_diff_line> LIKE LINE OF mt_delayed_lines.

    CREATE OBJECT ro_html.

    " Release delayed subsequent update lines
    IF is_diff_line-result <> zif_cts_definitions=>c_diff-update.
      LOOP AT mt_delayed_lines ASSIGNING <ls_diff_line>.
        ro_html->add( '<tr>' ).                             "#EC NOTEXT
        ro_html->add( |<td class="num" line-num="{ <ls_diff_line>-old_num }"></td>|
                   && |<td class="num" line-num=""></td>|
                   && |<td class="code diff_del">-{ <ls_diff_line>-old }</td>| ).
        ro_html->add( '</tr>' ).                            "#EC NOTEXT
      ENDLOOP.
      LOOP AT mt_delayed_lines ASSIGNING <ls_diff_line>.
        ro_html->add( '<tr>' ).                             "#EC NOTEXT
        ro_html->add( |<td class="num" line-num=""></td>|
                   && |<td class="num" line-num="{ <ls_diff_line>-new_num }"></td>|
                   && |<td class="code diff_ins">+{ <ls_diff_line>-new }</td>| ).
        ro_html->add( '</tr>' ).                            "#EC NOTEXT
      ENDLOOP.
      CLEAR mt_delayed_lines.
    ENDIF.

    ro_html->add( '<tr>' ).                                 "#EC NOTEXT
    CASE is_diff_line-result.
      WHEN zif_cts_definitions=>c_diff-update.
        APPEND is_diff_line TO mt_delayed_lines. " Delay output of subsequent updates
      WHEN zif_cts_definitions=>c_diff-insert.
        ro_html->add( |<td class="num" line-num=""></td>|
                   && |<td class="num" line-num="{ is_diff_line-new_num }"></td>|
                   && |<td class="code diff_ins">+{ is_diff_line-new }</td>| ).
      WHEN zif_cts_definitions=>c_diff-delete.
        ro_html->add( |<td class="num" line-num="{ is_diff_line-old_num }"></td>|
                   && |<td class="num" line-num=""></td>|
                   && |<td class="code diff_del">-{ is_diff_line-old }</td>| ).
      WHEN OTHERS. "none
        ro_html->add( |<td class="num" line-num="{ is_diff_line-old_num }"></td>|
                   && |<td class="num" line-num="{ is_diff_line-new_num }"></td>|
                   && |<td class="code"> { is_diff_line-old }</td>| ).
    ENDCASE.
    ro_html->add( '</tr>' ).                                "#EC NOTEXT

  ENDMETHOD.








  METHOD render_table_head.

    CREATE OBJECT ro_html.

    ro_html->add( '<thead class="header">' ).               "#EC NOTEXT
    ro_html->add( '<tr>' ).                                 "#EC NOTEXT

    IF mv_unified = abap_true.
      ro_html->add( '<th class="num">old</th>' ).           "#EC NOTEXT
      ro_html->add( '<th class="num">new</th>' ).           "#EC NOTEXT
      ro_html->add( '<th>code</th>' ).                      "#EC NOTEXT
    ELSE.

      ro_html->add( '<th class="num"></th>' ).              "#EC NOTEXT
      ro_html->add( '<th>LOCAL</th>' ).                     "#EC NOTEXT
      ro_html->add( '<th class="num"></th>' ).              "#EC NOTEXT
      ro_html->add( '<th>REMOTE</th>' ).                    "#EC NOTEXT

    ENDIF.

    ro_html->add( '</tr>' ).                                "#EC NOTEXT
    ro_html->add( '</thead>' ).                             "#EC NOTEXT

  ENDMETHOD.




  METHOD render_item_state.

    DATA: lv_system TYPE string.

    FIELD-SYMBOLS <lv_state> TYPE char1.


    rv_html = '<span class="state-block">'.

    DO 2 TIMES.
      CASE sy-index.
        WHEN 1.
          ASSIGN iv_lstate TO <lv_state>.
          lv_system = 'Local:'.
        WHEN 2.
          ASSIGN iv_rstate TO <lv_state>.
          lv_system = 'Remote:'.
      ENDCASE.

      CASE <lv_state>.
        WHEN zif_cts_definitions=>c_state-unchanged.  "None or unchanged
          IF iv_lstate = zif_cts_definitions=>c_state-added OR iv_rstate = zif_cts_definitions=>c_state-added.
            rv_html = rv_html && |<span class="none" title="{ lv_system } Not exists">X</span>|.
          ELSE.
            rv_html = rv_html && |<span class="none" title="{ lv_system } No changes">&nbsp;</span>|.
          ENDIF.
        WHEN zif_cts_definitions=>c_state-modified.   "Changed
          rv_html = rv_html && |<span class="changed" title="{ lv_system } Modified">M</span>|.
        WHEN zif_cts_definitions=>c_state-added.      "Added new
          rv_html = rv_html && |<span class="added" title="{ lv_system } Added new">A</span>|.
        WHEN zif_cts_definitions=>c_state-mixed.      "Multiple changes (multifile)
          rv_html = rv_html && |<span class="mixed" title="{ lv_system } Multiple changes">&#x25A0;</span>|.
        WHEN zif_cts_definitions=>c_state-deleted.    "Deleted
          rv_html = rv_html && |<span class="deleted" title="{ lv_system } Deleted">D</span>|.
      ENDCASE.
    ENDDO.

    rv_html = rv_html && '</span>'.

  ENDMETHOD.




ENDCLASS.
