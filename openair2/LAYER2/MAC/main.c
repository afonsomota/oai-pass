/*
 * Licensed to the OpenAirInterface (OAI) Software Alliance under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The OpenAirInterface Software Alliance licenses this file to You under
 * the OAI Public License, Version 1.1  (the "License"); you may not use this file
 * except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.openairinterface.org/?page_id=698
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *-------------------------------------------------------------------------------
 * For more information about the OpenAirInterface (OAI) Software Alliance:
 *      contact@openairinterface.org
 */

/*! \file main.c
 * \brief top init of Layer 2
 * \author  Navid Nikaein and Raymond Knopp
 * \date 2010 - 2014
 * \version 1.0
 * \email: navid.nikaein@eurecom.fr
 * @ingroup _mac

 */

#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "mac.h"
#include "mac_proto.h"
#include "mac_extern.h"
#include "assertions.h"
//#include "PHY_INTERFACE/phy_extern.h"
//#include "PHY/defs_eNB.h"
//#include "SCHED/sched_eNB.h"
#include "LAYER2/PDCP_v10.1.0/pdcp.h"
#include "RRC/LTE/rrc_defs.h"
#include "common/utils/LOG/log.h"
#include "RRC/L2_INTERFACE/openair_rrc_L2_interface.h"

#include "common/ran_context.h"

extern RAN_CONTEXT_t RC;

void init_UE_list(UE_list_t *UE_list)
{
  int list_el;
  UE_list->num_UEs = 0;
  UE_list->head = -1;
  UE_list->head_ul = -1;
  UE_list->avail = 0;
  for (list_el = 0; list_el < MAX_MOBILES_PER_ENB - 1; list_el++) {
    UE_list->next[list_el] = list_el + 1;
    UE_list->next_ul[list_el] = list_el + 1;
  }
  UE_list->next[list_el] = -1;
  UE_list->next_ul[list_el] = -1;
  memset(UE_list->DLSCH_pdu, 0, sizeof(UE_list->DLSCH_pdu));
  memset(UE_list->UE_template, 0, sizeof(UE_list->UE_template));
  memset(UE_list->eNB_UE_stats, 0, sizeof(UE_list->eNB_UE_stats));
  memset(UE_list->UE_sched_ctrl, 0, sizeof(UE_list->UE_sched_ctrl));
  memset(UE_list->active, 0, sizeof(UE_list->active));
  memset(UE_list->assoc_dl_slice_idx, 0, sizeof(UE_list->assoc_dl_slice_idx));
  memset(UE_list->assoc_ul_slice_idx, 0, sizeof(UE_list->assoc_ul_slice_idx));
}

void init_slice_info(slice_info_t *sli)
{
  FILE* config;
  char line[1024];
  char* read_output;
  uint8_t is_new;
  uint32_t total_reserved=0;


  config = fopen("/home/oai/cell-client/slices.cnf","r");

  AssertFatal(config!=NULL,"No slice configuration file");

  read_output = fgets(line, sizeof(line),config);
  AssertFatal(read_output!=NULL,"Slice configuration file empty");

  if(strcmp(line,"old\n")==0){
    is_new = 0;
    sli->is_new = 0;
  }else if(strcmp(line,"new\n")==0){
    is_new = 1;
    sli->is_new = 1;
  }else {
    AssertFatal(1!=1,"Slice method is either old or new, not %s",line);
  }

  sli->intraslice_share_active = 1;
  sli->interslice_share_active = 1;

  uint8_t s = 0;
  sli->n_dl = 0;
  sli->n_ul = 0;
  memset(sli->dl, 0, sizeof(slice_sched_conf_dl_t) * MAX_NUM_SLICES);
  memset(sli->ul, 0, sizeof(slice_sched_conf_ul_t) * MAX_NUM_SLICES);
  while (fgets(line, sizeof(line), config)) {
    if(strlen(line)==0 || line[0] == '#' || line[0]=='\n')
      continue;
    sli->n_dl++;
    sli->dl[s].id = s;
    sli->dl[s].pct = 1.0;
    sli->dl[s].prio = 10;
    sli->dl[s].pos_high = N_RBG_MAX;
    sli->dl[s].maxmcs = 28;
    sli->dl[s].sorting = 0x012345;
    sli->dl[s].sched_name = "schedule_ue_spec";
    sli->dl[s].sched_cb = dlsym(NULL, sli->dl[s].sched_name);
    //sli->dl[s].accounting = 1;
    AssertFatal(sli->dl[s].sched_cb, "DLSCH scheduler callback is NULL\n");
    sli->n_ul++;
    sli->ul[s].id = s;
    sli->ul[s].pct = 1.0;
    sli->ul[s].maxmcs = 20;
    sli->ul[s].sorting = 0x0123;
    sli->ul[s].sched_name = "schedule_ulsch_rnti";
    sli->ul[s].sched_cb = dlsym(NULL, sli->ul[s].sched_name);
    AssertFatal(sli->ul[s].sched_cb, "ULSCH scheduler callback is NULL\n");

    if(is_new) {
      if (strcmp(line, "PREEMPTIVE\n") == 0) {
        uint16_t rate, capacity;
        read_output = fgets(line, sizeof(line), config);
        AssertFatal(read_output!=NULL, "NULL slice config.");
        sscanf(line,"%hu %hu",&rate,&capacity);
        sli->dl[s].type = PREEMPTIVE;
        sli->dl[s].config.filter.rate = rate;
        sli->dl[s].config.filter.capacity = capacity;
        sli->dl[s].config.filter.tokens = 0;
        sli->dl[s].config.filter.overprovision = 0;

        sli->ul[s].pct = rate;
        total_reserved += rate;
      } else if (strcmp(line, "REGULAR\n") == 0) {
        uint16_t min_sla_rate, time_gap;
        read_output = fgets(line, sizeof(line), config);
        AssertFatal(read_output!=NULL, "NULL slice config.");
        sscanf(line,"%hu %hu",&min_sla_rate,&time_gap);
        sli->dl[s].type = REGULAR;
        sli->dl[s].config.rate.min_sla_rate = min_sla_rate;
        sli->dl[s].config.rate.time_gap = time_gap;
        sli->dl[s].config.rate.last_unsent = 0;
        sli->dl[s].config.rate.rate = 0;

        sli->ul[s].pct = min_sla_rate;
        total_reserved += min_sla_rate;
      } else {
        AssertFatal(1 != 1, "Slice %d is either PREEMPTIVE or REGULAR, not %s",
                    s, line);
      }
    } else {
      int priority;
      float pct;
      sscanf(line,"%d %f",&priority,&pct);
      fprintf(stderr,"%d %f\n",priority,pct);
      sli->dl[s].pct = pct;
      sli->dl[s].prio = priority;

      sli->ul[s].pct = pct;
    }
    s++;
  }

  if(is_new){
    for(s = 0; s < sli->n_ul; s++){
      sli->ul[s].pct /= total_reserved;
    }
  }

}

void mac_top_init_eNB(void)
{
  module_id_t i, j;
  eNB_MAC_INST **mac;

  LOG_I(MAC, "[MAIN] Init function start:nb_macrlc_inst=%d\n",
        RC.nb_macrlc_inst);

  if (RC.nb_macrlc_inst <= 0) {
    RC.mac = NULL;
    return;
  }

  mac = malloc16(RC.nb_macrlc_inst * sizeof(eNB_MAC_INST *));
  AssertFatal(mac != NULL,
              "can't ALLOCATE %zu Bytes for %d eNB_MAC_INST with size %zu \n",
              RC.nb_macrlc_inst * sizeof(eNB_MAC_INST *),
              RC.nb_macrlc_inst, sizeof(eNB_MAC_INST));
  for (i = 0; i < RC.nb_macrlc_inst; i++) {
    mac[i] = malloc16(sizeof(eNB_MAC_INST));
    AssertFatal(mac[i] != NULL,
                "can't ALLOCATE %zu Bytes for %d eNB_MAC_INST with size %zu \n",
                RC.nb_macrlc_inst * sizeof(eNB_MAC_INST *),
                RC.nb_macrlc_inst, sizeof(eNB_MAC_INST));
    LOG_D(MAC,
          "[MAIN] ALLOCATE %zu Bytes for %d eNB_MAC_INST @ %p\n",
          sizeof(eNB_MAC_INST), RC.nb_macrlc_inst, mac);
    bzero(mac[i], sizeof(eNB_MAC_INST));
    mac[i]->Mod_id = i;
    for (j = 0; j < MAX_NUM_CCs; j++) {
      mac[i]->DL_req[j].dl_config_request_body.dl_config_pdu_list =
          mac[i]->dl_config_pdu_list[j];
      mac[i]->UL_req[j].ul_config_request_body.ul_config_pdu_list =
          mac[i]->ul_config_pdu_list[j];
      for (int k = 0; k < 10; k++)
        mac[i]->UL_req_tmp[j][k].ul_config_request_body.ul_config_pdu_list =
            mac[i]->ul_config_pdu_list_tmp[j][k];
      for(int sf=0;sf<10;sf++)
        mac[i]->HI_DCI0_req[j][sf].hi_dci0_request_body.hi_dci0_pdu_list =
            mac[i]->hi_dci0_pdu_list[j][sf];
      mac[i]->TX_req[j].tx_request_body.tx_pdu_list = mac[i]->tx_request_pdu[j];
      mac[i]->ul_handle = 0;
    }

    mac[i]->if_inst = IF_Module_init(i);

    init_UE_list(&mac[i]->UE_list);
    init_slice_info(&mac[i]->slice_info);
  }

  RC.mac = mac;

  AssertFatal(rlc_module_init() == 0,
      "Could not initialize RLC layer\n");

  // These should be out of here later
  pdcp_layer_init();

  rrc_init_global_param();
}

void mac_init_cell_params(int Mod_idP, int CC_idP)
{

    int j;
    UE_TEMPLATE *UE_template;

    LOG_D(MAC, "[MSC_NEW][FRAME 00000][MAC_eNB][MOD %02d][]\n", Mod_idP);
    //COMMON_channels_t *cc = &RC.mac[Mod_idP]->common_channels[CC_idP];

    memset(&RC.mac[Mod_idP]->eNB_stats, 0, sizeof(eNB_STATS));
    UE_template =
	(UE_TEMPLATE *) & RC.mac[Mod_idP]->UE_list.UE_template[CC_idP][0];

    for (j = 0; j < MAX_MOBILES_PER_ENB; j++) {
	UE_template[j].rnti = 0;
	// initiallize the eNB to UE statistics
	memset(&RC.mac[Mod_idP]->UE_list.eNB_UE_stats[CC_idP][j], 0,
	       sizeof(eNB_UE_STATS));
    }

}


int rlcmac_init_global_param(void)
{


    LOG_I(MAC, "[MAIN] CALLING RLC_MODULE_INIT...\n");

    if (rlc_module_init() != 0) {
	return (-1);
    }

    pdcp_layer_init();

    LOG_I(MAC, "[MAIN] Init Global Param Done\n");

    return 0;
}


void mac_top_cleanup(void)
{

    if (NB_UE_INST > 0) {
	free(UE_mac_inst);
    }

    if (RC.nb_macrlc_inst > 0) {
	free(RC.mac);
    }

}

int l2_init_eNB(void)
{



    LOG_I(MAC, "[MAIN] MAC_INIT_GLOBAL_PARAM IN...\n");

    rlcmac_init_global_param();

    LOG_D(MAC, "[MAIN] ALL INIT OK\n");


    return (1);
}
