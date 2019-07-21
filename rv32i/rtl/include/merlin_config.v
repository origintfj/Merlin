/*
 * Author         : Tom Stanway-Mayers
 * Description    : Core Configuration
 * Version:       :
 * License        : Apache License Version 2.0, January 2004
 * License URL    : http://www.apache.org/licenses/
 */

`ifndef RV_MERLIN_CONFIG_
`define RV_MERLIN_CONFIG_

//--------------------------------------------------------------
// Simulation Configuration
//--------------------------------------------------------------
//`define RV_ASSERTS_ON             // uncomment to enable assertions

//--------------------------------------------------------------
// Core Configuration
//--------------------------------------------------------------
//`define RV_RESET_TYPE_SYNC        // uncomment this if you want a synchronous reset
//`define RV_CONFIG_STDEXT_64       // TODO
`define RV_CONFIG_STDEXT_C        // uncomment this if you want to support RVC instructions
//`define RV_LSQUEUE_PASSTHROUGH    // TODO - broken (comb. loop when enabled)
//`define RV_PFU_PASSTHROUGH        // TODO - broken

`endif

