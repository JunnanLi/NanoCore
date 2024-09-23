/****************************************************/
//  Module name: ariane_pkg
//  Authority @ lijunnan (lijunnan@nudt.edu.cn)
//  Last edited time: 2024/05/23
//  Function outline: 
//  Note:
/****************************************************/

package parser_pkg;

  localparam HEAD_WIDTH       = 512;  //* extract fields from pkt/meta head
  localparam META_WIDTH       = 512;
  localparam SHIFT_WIDTH      = 16;   //* alined to 16b
  localparam TYPE_WIDTH       = 8;
  localparam TYPE_NUM         = 2;    //* each parser layer has 2 type-extractors
  localparam KEY_FIELD_WIDTH  = 16;
  localparam KEY_FILED_NUM    = 8;
  localparam RULE_NUM         = 8;

  //==============================================================//
  // conguration according user defination, DO NOT NEED TO MODIFY!!!
  //==============================================================//
  localparam TYPE_OFFSET_WIDTH =$clog2(HEAD_WIDTH/TYPE_WIDTH);
  localparam KEY_OFFSET_WIDTH  =$clog2(HEAD_WIDTH/KEY_FIELD_WIDTH);
  localparam HEAD_SHIFT_WIDTH  =$clog2(HEAD_WIDTH/SHIFT_WIDTH);
  localparam META_SHIFT_WIDTH  =$clog2(META_WIDTH/SHIFT_WIDTH);
  localparam TYPE_CANDI_NUM    =HEAD_WIDTH/TYPE_WIDTH;
  localparam KEY_CANDI_NUM     =HEAD_WIDTH/KEY_FIELD_WIDTH;
  localparam HEAD_CANDI_NUM    =HEAD_WIDTH/SHIFT_WIDTH;
  localparam META_CANDI_NUM    =META_WIDTH/SHIFT_WIDTH;
  //* shift process
  localparam TAG_START_BIT     =META_SHIFT_WIDTH;
  localparam TAG_TAIL_BIT      =(TAG_START_BIT + 1);
  localparam TAG_SHIFT_BIT     =(TAG_TAIL_BIT  + 1);
  localparam TAG_VALID_BIT     =(TAG_SHIFT_BIT + 1);
  localparam TAG_WIDTH         =(TAG_VALID_BIT + 1);
  //* replace process
  localparam REP_OFFSET_WIDTH  =$clog2(KEY_FILED_NUM);
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//


  typedef struct packed {
    //* extract
    logic [TYPE_NUM-1:0][TYPE_OFFSET_WIDTH-1:0]   type_offset;
    logic [KEY_FILED_NUM-1:0][0:0]                key_offset_v;
    logic [KEY_FILED_NUM-1:0][KEY_OFFSET_WIDTH-1:0]key_offset;
    logic [META_CANDI_NUM-1:0][REP_OFFSET_WIDTH:0]key_replaceOffset;
    logic [HEAD_SHIFT_WIDTH-1:0]                  headShift;
    logic [META_SHIFT_WIDTH-1:0]                  metaShift;
    //* data
    logic [HEAD_WIDTH+TAG_WIDTH-1:0]  head;
    logic [META_WIDTH+TAG_WIDTH-1:0]  meta;
  } layer_info_t;

  typedef struct packed {
    logic                                           typeRule_valid;
    logic [TYPE_NUM-1:0][TYPE_WIDTH-1:0]            typeRule_typeData;
    logic [TYPE_NUM-1:0][TYPE_WIDTH-1:0]            typeRule_typeMask;
    logic [TYPE_NUM-1:0][TYPE_OFFSET_WIDTH-1:0]     typeRule_typeOffset;
    logic [KEY_FILED_NUM-1:0]                       typeRule_keyOffset_v;
    logic [KEY_FILED_NUM-1:0][KEY_OFFSET_WIDTH-1:0] typeRule_keyOffset;
    logic [META_CANDI_NUM-1:0][KEY_OFFSET_WIDTH-1:0]typeRule_keyReplaceOffset;
    logic [HEAD_SHIFT_WIDTH-1:0]                    typeRule_headShift;
    logic [META_SHIFT_WIDTH-1:0]                    typeRule_metaShift;
  } type_rule_t;

  typedef struct packed {
    logic [TYPE_NUM-1:0][TYPE_OFFSET_WIDTH-1:0]     typeOffset;
    logic [KEY_FILED_NUM-1:0]                       keyOffset_v;
    logic [KEY_FILED_NUM-1:0][KEY_OFFSET_WIDTH-1:0] keyOffset;
    logic [HEAD_SHIFT_WIDTH-1:0]                    headShift;
    logic [META_SHIFT_WIDTH-1:0]                    metaShift;
    logic [META_CANDI_NUM-1:0][REP_OFFSET_WIDTH:0]  replaceOffset;
  } lookup_rst_t;

  localparam  LAYER_0 = 0,
              LAYER_1 = 1,
              LAYER_2 = 2,
              LAYER_3 = 3;

endpackage