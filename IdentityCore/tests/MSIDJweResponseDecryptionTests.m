//
// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files(the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and / or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions :
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.  

#import <XCTest/XCTest.h>
#import "MSIDJweResponse.h"
#import "NSData+MSIDEccSecKeyRef.h"
#import "MSIDJweResponse+EcdhAesGcm.h"
#import "MSIDEcdhApv.h"
#import "NSData+MSIDExtensions.h"
#import "MSIDJwtAlgorithm.h"

@interface MSIDJweResponseDecryptionTests : XCTestCase

@end

@implementation MSIDJweResponseDecryptionTests

- (void)testJWEDecryption_withCorrectJWE_andValidKeys_shouldReturnDecryptedContent
{
    SecKeyRef privateKeyRef = [self testPrivateKey];
    XCTAssertTrue(privateKeyRef != NULL);
        
    NSString *testJWE = @"eyJlbmMiOiJBMjU2R0NNIiwidHlwIjoiSldUIiwiYXB1IjoiQUFBQUEwRkJSQUFBQUVFRWdGMTVnVVYyTTlTN2QwbXRWR1oyWjYwT1JWcDU3bW9OcXV3Z0gtY0xuZ1pfZnV5cHdLay13MHU3NVpweGI4aGVzOEpqM1JmRlhFUms2c00wOFBDamZRIiwiZXBrIjp7ImNydiI6IlAtMjU2Iiwia3R5IjoiRUMiLCJ4IjoiZ0YxNWdVVjJNOVM3ZDBtdFZHWjJaNjBPUlZwNTdtb05xdXdnSC1jTG5nWSIsInkiOiJmMzdzcWNDcFBzTkx1LVdhY1dfSVhyUENZOTBYeFZ4RVpPckROUER3bzMwIn0sImFsZyI6IkVDREgtRVMifQ..SX-DF8aCde6-DmjM.zxQj6BPXmIXb63-3_p--ydQpQde9n4I8a-_9LNuhFvIlN4YfFOpPv6JquITho4dASgLiuL922072vicumPuEYvgjL8E6dovXveZZcaAnS_sv0fKBO8Ra0Nn3EL08D4uV3vxei8JCEg2HlllPzI7wCCHmZ8pI8KUBi7Ti5pR4ILHVfUMgE44TBWvkF5uOZG8WLwHrwPduWXHw1Kpe1F6-mxgCmBX1ZJ0d3mDbBjyeNNz7C5W4lHSS4KRO7D56PCZrAkT3qSvPLhPQDtvZRtz8B7PE8quyXtdlUEtYbpv9Qsv0KtQXGgS8FR9zzXWNSa19xYh3cC6Ggy_fML9uPs-Bl32BnY_aKmc2FC3jubo2Z5iShF7kHn5VaCywYLuniN8TwnAf1ca6toNF1IwiEpKv8WtdpGj6Ptzl5sSe468qHbU2ToYPcaUehSL9Q5WtE8-lwvdetOsK3gt_dw3TJi80NYwKe3fkQyoG9rC9f8RHgqxOM9ov25aBNpwFyT4pb2mRinkH8gK4zGegadO6odsmj-REwtjh6DWs_LfRIxbtWqAvo_2n4tlEyiKdVh1QhupKb2HLgLt231sACJW9iljAbOd9kUjVayp2jYxoRDXsI1pKD9qpRf3abl_FmvFOfo1asMfg5UueL-eR7NYnIXU_jgYgRXtaKyr32ROIcSAlj-r5Qr0DyRAjPgD0k4x25EJ9M3dOSUbn3KpUx4OrIhrpkxKMFTkfNnxifG9roKRm6bOgoVFX0SLbG-9dLD0gwljFVtv2CRU6NSbO1IW-ek-dB2W5k3dqcYWF3rbeJ1LOiZK-dUlIyNQ6VDM3rise1KFi5F3Ok_NgM66iPAYTwBCUQRjubFh42xI0mbhm3cL4AxMU9-v91C31E25vBojRAUSyHK4A5BlgjNVNyJ6hiXyqylNxnnKCfbf6ykniDRezw3PZKNJrhzQOW5ut5j_7_aKflVzQG3NRrDAV2h1OD59EuLB0jwzFk_DJU9eOvE6bl9FhXjiMlp3ZoI18bFKxQlAuS55u5j6WFSRmzouMayrsX5rEeTWw2JXigCc3hvlPLaNyn3SvZgVEMp-gFbKd8xBva59RQz4ow8Bji4YPlqciwXK0qS67ZbL3zOFfjSHw4TIf-iNs9ahToLUo2yxPQj3jkmErALKU5cfzTkMu_p4iY2OCzahRlX0utr2T6Z2y0iv18bVvHioP2HBtKU0h4X5z8xNUWGgLcR6RRCUdvaURcnGBSE5wfzd41Uapx6TCZsXyxkAEKioRSOB_A0MeWjqGYTOxO8DAIaDaFSA88c44gpXLO0Nui_xBiz0ReqUolDO2FwypAPSIea_Ccw3DnJyBRbiQmVSk70RYkxHGPrZTiODnluDinQVvv811QFXM-jIYDS3ZTMJUn_XlVC4pHRre6ucG95BKzLMmPyOlwhARNyxrmibLaVZLuuqLkWCrfeEumyXCFW9r1eAyOaGy6F4M5Rt3AMtnuQmDNaT6hKFkJFZHKpBTQ1Zy25QjwbRbr827WzyXFoLgiqII_feZIVfGocQF0BZsgsM3oQgX3u5ePY_gJ7yxPfr6N-H_h11I_73_8U2dVH_O_xCpZ_T-Rn2jOF_KckzusbnWHXDdN0lJ8JU8yk9_m-PN9T2r4Lh627fIR5ifFrhO9__1K1Fw9J-GD4I6Dfn4QF2vo24dpBG2rHUD0I3qr6KRPr9r2ibLOX6B0SLEsbYbWYtt8agZ8ObiFIfGS7TY1g4Az2zzFGAMEsnLU5y1ypakypP0zkLIl6pHKVaZBOkIV7jYCOtv0S8JdOTzs42bjZrzr5UtrI4ko5vRwNsL9MACWg58-qa0W6eSE8KNy0PGjqAK_f4fhwD5fv4h5ogkkGdz-UUH8WL1L7AYIzBGv_LkD6j8YvSZSrpdPZUrXHutkj--fHq4NSWGIQqIC5GsCAOqmaTWSJj6JenCxLveGMtC-uDasaBMPfi4t_DQDn4DCqkS88Ycjb8IuCdF233UqxNi_pylFVS7GVZVn033j-OfaTmkbomRl8mgm6l7VEoCO7eLa9Xu17eh02nLsbLVUd529bMsE4gEva4gXM1awcmcKLnfXKr-7Em_2OpeF5wR57uniufcS2Kqexjh_pQRdPV6NEXnghSBnF3PI2fUDPqkqV7TBLnmJhJk15CImkj-hrQPGcTRTW7t06kgQ8UqMaMQRCS3a6K4KdD-OHhDTg4MbHhYGSSojAtnT7k2TZGnW4sYZnA7cK3str9MPQ66HYpm_eXzI2L5IyDawXxuCr63ZaZMhJq7gjQgV5CFQWQtpDzwd93Nhl3-tYGsLQKX4-sDDUXLlGsobwvcQ3zaF_P3Lh1250LHzs2NLK9cjD8Q4vlLBI6JHL7yNN-07w8K8n-A3_sxrJ_92KCwnoxH6z3dtriOEapVAE9jW6MB6YhVw94nDkx7TGSNdudO1xonC4wboCd_urnZwI8pZ3pSLw_4K5IxIWfF18MjQ1iqAKu6Dm-YggmSglfgaS7hrhjv9uPC66bGGZSDF8eofm1lBoYCrzEXLpFGNTXBHObTeHhkk33E5WPi2jo6XDxzr5CojPz_flPWyTH2oftqb-f9ndPbIRNvR06PhQisJvscoKdv-my8Ecb8Es2FQMxbBa7K_1w6Pt7HAxC7uak_GGElDR5X7kmg9Dd4gs49oVE2PQELbGt6_857vKk7eyCHiCkHsZc7nVDRI2N9ElN68qp0u_CCRjBwZ6oZHLJRdj6jqaZo2taX2p99aRN5ybrQBxXGHcgBMj9V9mGCBBNry4Ifnlna9LNtj6uDaYQVtZWsawDkVdsgKYMil14TlUvpGlFAB6NJqS-98CyB6tuT0uGIWqStzZqJ323dD9qpfSiGfeyjKizZzl5YztzUD_JBg2glS02cWLs-G76m5pGo9UV-lVWJbD5ognxHtBqim1fJBPiTUAvTw7kHt6ZyLLRnhTImJb-EthiUE5A2-ku-tdn7lxydI7pvadHEKVlRPjiMZPMqsRozrG4rWrYh87HUHBkTvjc3MNt9ms48WkTmnMujort05w6vi799R1gWxPB_heKBKhTsOiTROVLR720F5nqyfpuFy5DkktI0_LEMZQOnsaGrXeDs1W79IxSvy5jJqLrS5bAcjcKpWFK_zWZi5b-DrNxB1LrM-aWZAvdTXaQhFYX7LcqV0N_TGe93Wi_sUYVn97STPEsaMhh3teGm3qA2DCK0I1JthKN_-ICciBguUKDvN32NP_fNFqGd-9JooN7URljLGOHNg9ZsTvLZnDKhq6kWqiyt_otfU7V0XlFISxcfb-AjImdKC3QvExtxf8sSxNTAakV1uijCWANqrWODaZb9lYHW3qauiw2KssdvoMiZTUCb4rVzt9Sv6E4gAh2b2B1GkQEfb3Wfgvm5Fl24vT1eswLRx-T4kl7LuSL0z1aj_hie5lZYG6qMeQZS1030wVGCjzEu1AQbhlG40asVBATwINsWDLT2K5zIvv__j1iCutM9fmv7b4XF1C5Q7wQe_F6HLFbvDCauyRCwUqUniAWwrGuqDVcE6rIZUXOxB5HBTKqze2vCk4tqW1kldxFLPH8OYAw904MWRbSXHJ0dFxnxSDPcMztacXCqrb1BsJgR_w9eksT95-2PKWC05cGm7Xhlw_4dX4GWM_EJNQsuEVXokxFTtS5HrIcsPu9oip2ReeGLYCc1cA7zZJtFEkqxpRfmLfqM9uqq4uPc9OKFnhmiLq5aQfgv_SGBeR9nLf5zJs2oSJdHHn0JMqSxjM4LxyDfd_245BzIZscBoXPIKSx8tx3fbsV7twRpYpoa1moNR73fRL_Co03Lj2boduN-vXUsFqJ7mM5jmFSV1mpeSCi8F6EqbukDeVaagS1bC4cvhipmNThdYlD7tR5M8XW42VfMKyPGNhqJLX6tgFGWgn-iLe2Jqthvm-2s_xidzVwSVCpq5DrlNMebApy5RBtVwtmD7XvjTeWl57QBKG_7IO1zyrSeH94_jQlcM2FOPlcMo9iirujDb5S-pGIcB0Bw0ARhiYlein6UqzXsjVqTAXdM6-MgjDjBwXLhCKdIC1NofCPA2g6LGk5MgUQUdj_d8Xu2nmJHFzEVvnvsBXjNGllsBXI9yEF_t6f-o-bmSDJLfEPMP1gjMFcaTUMXMgzSLmQPLolACfQyJRrIAx6A9lJhlIXMXXwylOVKStPzwMnCpDx1WMSgGTphXzCIR5YVjzvsebIeppnu9ystd984EaGNfKa73TRhV8C1jOzCnG6aYww6eSlLOQXUaFRYA48z_nmHWsY7_FdQswuwUYWhhco6ROyIGCsFwlQsZeuYZHTMLjUWvi_hQdZHVCFQZp1ohOoUzeWUg5JAm9dsqvaVotIiv31rsdH1XZUEyHoPQLkl0jAASTqizqZ3P5nkG1xbVvnHKibelIz7A-LgEhZZE6rD5dsZAguhQ-Kpo2uYidJz0MoZvNIGpUF0rtEqMrCC6LJnyqabjZK102bRC34lD_klf88QygJAmRpjtcptIcYFpCK85V97k5Wl4CzP-1hclWyfKmITFmbfNjO2Pb-05TZxHvgXNijLFNK-y7249shuLttYSZt1eAgL0mkDQUsKN8JSaUivIl68h6aTYgnxnoz5FFuU7qY99zBOpLBrRLNdVrjs8chLX_gbTqCQ0BViBcI8Hb3E4zk3Pt6RJLwnW-mNOxpb32ONvc3MvPP_-uomfQDejlCr1yogNtjfSNjXUgfUR4IVD0ucy2D_As5MTWmXoXplHJG5BEcyemfenQHr-iuiA8Q85KljFR_ZqIG-xSek3jAF1DPjZERKYrzb75bLsHEJk4nvt-BgTXAEgd00MwJpP2XqStnYYbNjUUDgE-SfiqWh1VZ3hE-oi-PVJZjs-dkaBVxqO2Iht3nny23aoK_yZQIu5GXl40sZMmp1bJF6QuUEhiBnCpPKfvxunwBYSAZSEZ3aq6NXJDEj7ducm352oKnto9npzZml9rbd42-PnLwY9RoiKRhh1d4ABEBpJ4l1zk9h27OC0HooYlXFXVzCTUhtJdcrxM9fmT2pgDljv7O6b_utadkpwi_cY3AtMcOJl71gDIm9_MVJxZzY7sbgPA0wKwqYkmOq3QE3Khjioi3ttTHA4tVl7-XuyNpSq3N1JEK72jviqGnT7lW7rnSgkGWK7EJ7Efp3dzOvfM7YhXMTyvY2kK91z_H7B-xnIXiEb6RF4hNS6mrnpuhW5xvUTo-4ApYGhf1Wt7Ld2K_qdT0LATuVaCPzD9imIPScuHm6liIDYwrknfsONlUALYPytq44myiMrht838ygwbQMXWv1T8KkS46lcR53Hui7VmeBw4b5iyMsa26vmxWwSR7VVECKnHfh3nbK0ayMqCRJOCMNpvsmFRnNFDJ_zao4MpggrmNONFPR9zz_uSGc_SWn3FZuCyBh9pvjbp0I7ao_7VKLfRPIQ8YhQNM6W9e4UAB0ikURMk95TVMuM2lU93ekmgYfUURet9GsDJUTPLTKcFO-oe5inOvb2DFICIYVJJiBcPfojybiIW7e9968aqTc0U1HbHEkuqUNptjpOlQuJo0GI03ZQoa0ESRyMHSwiUddQYN3NwjlFSIT9AUz7oIiQS5ElGSlcbfl9xq_iY5KSlHpFF8-3dKxJpYxsViy3zMp8vQBlB5rU_F0vQTOtdwlb3LJ1TFb1kcVqqOt5MYLyfko9i4c96pZEVhRRGhm_HdMHqzRuYHq0uyLrNCD8VigB6kGMpErqO87lU0fOLgp3Y1xGxz8loVJygqfn6OzF4KGFZ_8S0YLlXi-g94mhvy14LUcn5RgLXjQF1EnWyKn_HV3diwhQYKRK7EwWabIetoSSFUb9Z8RvM7aAvr9sG_bTYETdj_betxBbHmhRSnHl0ZAJ15QfUhXnQyfpWebzWoZ50FZp6ZAksp0RlgBVsPbusnLzLe5_7rdb7fNjK4dygvW0zhhTU7FodXv6nw1KogBQilWLFy7TCo-fLWwNhLdJX7E_kK022F5nC706Fye3OJJNJeoaIea7nWaIzOORwEjEPduQp41IJP_0W2wyAXw5QV_U74J-nn-XgTZUXHUrB6sfZdmJBS9JGXLHXQ5td79JM24V-hZDlpNPYWomWt71nk9HSog3sbLH-omGoc40IU9Bh9O8SVpdvDznAELUt2TSxh_AG3RjqtB3hmQsFqcqGSLBCHzHUuLJab4FsoFs3EeL_ZUqqQoTk1W6hWbPLcwMVH8CfW0k6tNR0RBffyzicAXzbEx5rg-ssyslQDh_OAoNWHwM193oP9v7sSY0D95wcIzAJIodtpN-W_i_pwpKNh-_db9vIh-0RVdi35L1cXOwa5-I5RPAPqdA2Dh7EKfvkQTkR1_Knd7hbXxVoQxuu26yBeglxB67nX9NW5NWJJ2SHPz0SiueIgno1JT5_MwNKYzHPZhDr4CzX8YVqiUch0oThUSndvydNSn6U-L4uDBwx_R7cvpcv7yQmj7m5fgs1Yrq8TbsZ5wDPl8ZrBRO9bqZsz5V4yFnZgwoknwPI00UXH5JtdladM1Pf0ySlUjJEaLHUheOQJVxAl8TDs2FQtu6T2v_gornJTK2Sd5YYQLi9bfeCi0K7ClGvarGcJaZGIFhQLj7kZC2v2S-HO-3LiQAX8nsMhWGyOAByqEHjP0KrDt2P2B3tETbmZUkbGCHU4eO69fluW8LRDumosAF4iAwuDEUjmzNLxeVsXFH8sM55QHOpjuD9-ntktjp8Hn3ec2cMDZIJpuKTopWepUJ-Rg2olmr81p83WzHtmFTnJlqegTwTSNk1vSeyHsYaTjcDzO32ay92Ayt0jTwHwnlV-_PE8D69H797BuTZWl9AT09mLcPjR-AbX38mcGFHSRgXoFueS5KEak0PlIAvXpA8Qt2Bd4kZM88tW_Oim3JuJWkI8lNI98BOHxGVA8FgXkfObFuqJ1IN9sfSXVjxW_1XToDoayWpn3lccTNq81nHmtMQL9LknZu3d4sZGDCkKZ6cSQBp51i38WwJwOvt5fY1dhEXLoPF2YokHlv0J7iCMulaYYc5nNDN580uxO94nGr-sVpTIr4SRCpRnUkHpqr6LcVFkPPQlqoHbjtWe8_GXGJB9bgD3kHXjRzKo2NQyjGiv5nHFiAYXOO-8FfxHkbHvmj_AGd0AMB3tomCciWyEbScXRelt65qoRqCmEOiK211K-eWQr6MaGm5TY2R-Ipn7fxONuS_nuj1tDwU9tHEw1vy1VpaqN7noYAFTfLP-SM4MB9WDnIm7-Hd95OmZAvFfDXnp2H8AD66gqiVKuw8e4LrI7lRomk3-VYuUmxa_Cqczb3_rlvuAzYjOjB97a2HF_l1jt8Ybp5ShU64JHR894_J5gdj3Q3ss1I1Vy5DqhdYU0IRF-0LdnPZ0CuY16KgkDllBVUASJWz8nvrbHAPtttC1MDRGm5pGWEpQYn_cpHnKB9H7vBAbuPSVdEgnZHilDzYtJ3Tc3gKzuJTaLR_HjMxxk4044J-Q5_M56vZeBRc3YvEHRxZ6FWfDo65NUx9vSFc6B.W8jTScz4y2rKrVr9k8hCtA";
    
    MSIDJweResponse *jweResponse = [[MSIDJweResponse alloc] initWithRawJWE:testJWE];
    SecKeyRef publicKeyRef = SecKeyCopyPublicKey(privateKeyRef);
    MSIDEcdhApv *apv = [[MSIDEcdhApv alloc] initWithKey:publicKeyRef apvPrefix:@"MsalClient" customClientNonce:@"0432c370-dec8-42ff-a28a-1317339cb8fc" context:nil error:nil];
    
    MSIDJWECrypto *jweCrypto = [[MSIDJWECrypto alloc] initWithKeyExchangeAlg:@"ECDH-ES" encryptionAlgorithm:@"A256GCM" apv:apv context:nil error:nil];
    XCTAssertEqualObjects(@"AAAACk1zYWxDbGllbnQAAABBBPpRRDIGtje9UcIvoQ16RUctNiuAKyhjB23eBadK2nQas3JmKxqfxRHpcT0uOBY1QH4IiumqK38h1WsIkKgJVGEAAAAkMDQzMmMzNzAtZGVjOC00MmZmLWEyOGEtMTMxNzMzOWNiOGZj", jweCrypto.apv.APV);
    NSDictionary *decryptedResponse = [jweResponse decryptJweResponseWithPrivateStk:privateKeyRef jweCrypto:jweCrypto error:nil];
    XCTAssertNotNil(decryptedResponse);
    XCTAssertEqualObjects(decryptedResponse[@"refresh_token_type"], @"bound_app_rt");
    XCTAssertEqualObjects(decryptedResponse[@"refresh_token"], @"1.AAAAAQAAAAAA8Q_OAAAAAAAAAKJ9xHIEkMhNlgJTKd0Pby4AALkAAA.1.BQABAwEAAAACAOz_AQD0_2wk_d10Wos4dOKsLGCHt2EBPpXlc6RcqmkzvSuF6ba1cA4p7SpWachC1ZybVTHIM0fY1TMIcFqM_ismC3m1kA1_STk2e1VOXPmKfLxGWVKM6hyOgpBXBLUnX5tXDQEaX_hQpKWJYElyAe7wrI4b6Fw2dd04N52AZDY_XcMiYm8ZGKEmXROyF_uFqeoSxaad3usSX78LIGdJO0I7vz79lX7PDFCabH1oigV53cwO-2j-fgddURm_Gdh9HMG3p8UgUwI-olJkHdSB-D4BHi9JuJhQ56HpWuNXTA9nnRa6R0TxOhWg2HWNM-oK1htrSephsE_V9NSJUQb8lQJjEqWrSumMQmqEcVhZwM0nOKt3s4kTv8EjRv9zorb_s54Wzri75JzJge_bB-rMuQ8qHnPvtWlACMd2eHedZOlxTG1C-v_y9FKwMeGza7SlaUm3fKwsIAkYvOXQOCCxC4MTuGxUvIKqEx1FUCKtFZIUANAH0wuw1Q3L2H4mf1W7WFbzeDDCJ3ebRyfUAs2Wi7nrEgIAs6djAoTFzJS-EMOMGYOn2zufglfKPa_K1LOypBCHPrPAOVaV9ZIWXsa92Gohg8jmYGoSbgImqePIvVeZeUbaV9lZDT7FsygE7Xa9if4Yu2rd1qghBSjvShX5bVAXUhkBb0K7pIZchVOlgQ241g_7EYOixQvsnsVQAdof7xlF5PRJApB5NufEQ6sClnFNw-LyIT_XpHe-Jl0oor8bB9IMoSkCj6ssqUhiNnhUjZULI0rfRD4R4yLHxDE41pDhGNByRh_0binp8hAJ7radIywU7Dwm4URf8FGSAPYuRWLYfeyxPpsieso37t8kVvUqnIyeHPRiTYXhBSQUYjHY_T2cn6l08xfVMhoRsEj0x-xZ8EkQJGCFfYdZ2tuxpqLqkYChovUjVA0mGuTLgpdmM34lawaSs8n9SsrmTooR3uNhT6wxjEjabPXRLZQyqQIoUlhXKX4Yz3enGshk6JZN8viJJvb4HP-45-nJyn9p9w9gftwefZEmqxIK4qHxprqZC-VQJA6gnHRTlzwuBNiQXQSAwNT_-ar-jnO08Jd6DpfZkHTf-DBNpBWlzrx2Y5ezHE5pobukBgtS1RQCAW1BLiXYxnpBU0VopN5JDrk_cjy1mPaLbAXKysc6f3pxHGyTfjPr3rVDZbVOQLwwBllRQViJ4LyOaa8IqHD1Z5ylErD2_a18JeVNyjjYI1RM4vDwSe3mcG3jgAfbgrvym-YkKus0i4B078ekToxgEOn-jree6H9VScvfTEgaP86uARL_8CE6rAGq91mZNpbw5rx7jg2syQUyf-yRZymOooCEwYuPDa5NIYIiAhj1jOpooxP1USThil9FhUiONInZyqynCbwGTV0fPOvVwM-bQLtMFkl82uO_-f9qXlFZZ2N9VWHCvIn2Yl1AORE0vR3b9b5pjoWZO3P1SuIvTKJBUYGWbbyMY1R8HmCp-l_mPKdu6YpEvySfz-_8V5H4XgYWFG5nxDi3TU6Iq28NCkI1VWj8xtZsBI8qIgDE_vjAfuQcrM6Jg9l54ZnFesc2fgv3F2ricp1G9RnM15m7jZSUbHtDW2QOOzjZzlgVtHpt3tvAXxf1YVjAoGuFD_udyE81urEtFholjBWK9AJVELhBdQwpPMAzwvtNFucIWddkwGIa0r6i.AQABFAEAAAB7jlZc__D7QYSWZvayy41QsrxzZCqY3BGD1qLPYdkmIA3zY72lupErGug4EQNkTShbDWSKW4b1KQcSFuCfV95iOWLzFgDXkLfL4jDoihxA0wwGn3HaL49K6TvSnR_HEpFlQP1LKFfJkcFih0rKn0mzwaYaYiZAcajRL_GCPZPk7YSLoD6UZN3z63pdyjaKbaE8PLzJHFuhxc4Kka4WzjAfeinDyt9TBnnKKEhCIEEA0ZwtP8LnAZJ_ByFwMJ_PiesgAA");
}

- (void)testGenerateJweCryptoWithTransportKey_validInputs_shouldReturnJweCrypto
{
    NSError *error = nil;
    NSString *apvPrefix = @"MsalClient";
    NSString *expectedNonce = @"0432c370-dec8-42ff-a28a-1317339cb8fc";
    SecKeyRef publicKeyRef = SecKeyCopyPublicKey([self testPrivateKey]);
    MSIDEcdhApv *ecdhPartyVInfoData = [[MSIDEcdhApv alloc] initWithKey:publicKeyRef apvPrefix:apvPrefix customClientNonce:nil context:nil error:&error];
    XCTAssertNotNil(ecdhPartyVInfoData);
    XCTAssertNil(error);

    MSIDJWECrypto *jweCrypto = [[MSIDJWECrypto alloc] initWithKeyExchangeAlg:MSID_JWT_ALG_ECDH
                                                         encryptionAlgorithm:MSID_JWT_ALG_A256GCM
                                                                         apv:ecdhPartyVInfoData
                                                                     context:nil
                                                                       error:&error];
    XCTAssertNotNil(jweCrypto);
    XCTAssertNil(error);
    XCTAssertEqualObjects(jweCrypto.keyExchangeAlgorithm, MSID_JWT_ALG_ECDH);
    XCTAssertEqualObjects(jweCrypto.encryptionAlgorithm, MSID_JWT_ALG_A256GCM);
    XCTAssertNotNil(jweCrypto.jweCryptoDictionary);
    XCTAssertEqual(jweCrypto.jweCryptoDictionary[@"alg"], MSID_JWT_ALG_ECDH);
    XCTAssertEqual(jweCrypto.jweCryptoDictionary[@"enc"], MSID_JWT_ALG_A256GCM);
    XCTAssertNotNil(jweCrypto.jweCryptoDictionary[@"apv"]);
    XCTAssertEqual(jweCrypto.jweCryptoDictionary[@"apv"], ecdhPartyVInfoData.APV);
    XCTAssertNotNil(jweCrypto.urlEncodedJweCrypto);
    XCTAssertTrue([jweCrypto.urlEncodedJweCrypto containsString:ecdhPartyVInfoData.APV]);
    
    NSString *apv = @"AAAACk1zYWxDbGllbnQAAABBBPpRRDIGtje9UcIvoQ16RUctNiuAKyhjB23eBadK2nQas3JmKxqfxRHpcT0uOBY1QH4IiumqK38h1WsIkKgJVGEAAAAkMDQzMmMzNzAtZGVjOC00MmZmLWEyOGEtMTMxNzMzOWNiOGZj";
    NSData *apvData = [NSData msidDataFromBase64UrlEncodedString:apv];
    XCTAssertNotNil(apvData);
    XCTAssertTrue([apvData length] > 0);

    // APV: <Prefix Length> | <Prefix> | <Public Key Length> | <Public Key> | <Nonce Length> | <Nonce>
    NSData *prefixLenData = [apvData subdataWithRange:NSMakeRange(0, sizeof(int))];
    
    // Extract prefix length from apv data
    NSUInteger prefixLen = [self convertHexBytesToInt:prefixLenData];
    XCTAssertEqual(prefixLen, [apvPrefix length]);
    
    // Extract prefix from apv data
     NSData *prefixFromApv = [apvData subdataWithRange:NSMakeRange(sizeof(int), prefixLen)];
    NSString *prefixString = [[NSString alloc] initWithData:prefixFromApv encoding:NSUTF8StringEncoding];
    XCTAssertNotNil(prefixString);
     XCTAssertEqualObjects([apvPrefix dataUsingEncoding:NSUTF8StringEncoding], prefixFromApv);
    
    // Check if apv data contains the public key
    NSData *publicKeyData = CFBridgingRelease(SecKeyCopyExternalRepresentation(publicKeyRef, NULL));
    
    // Extract STK public key from APV
    NSData *eccKeyLengthInApv = [apvData subdataWithRange:NSMakeRange(sizeof(int) + prefixLen , sizeof(int))];
    NSUInteger eccKeyLengthInApvInt = [self convertHexBytesToInt:eccKeyLengthInApv];
    XCTAssertEqual(eccKeyLengthInApvInt, publicKeyData.length);
    
    NSData *stkPublicKeyFromApv = [apvData subdataWithRange:NSMakeRange(sizeof(int) + prefixLen + sizeof(int), eccKeyLengthInApvInt)];
    XCTAssertEqualObjects(stkPublicKeyFromApv, publicKeyData);
    
    // Extract nonce length from apv data
    NSData *nonceLengthInApv = [apvData subdataWithRange:NSMakeRange(sizeof(int) + prefixLen + sizeof(int) + eccKeyLengthInApvInt, sizeof(int))];
    NSUInteger nonceLengthInApvInt = [self convertHexBytesToInt:nonceLengthInApv];
    XCTAssertEqual(nonceLengthInApvInt, [NSUUID UUID].UUIDString.length);
    
    // Extract nonce from apv data
    NSData *nonceFromApv = [apvData subdataWithRange:NSMakeRange(sizeof(int) + prefixLen + sizeof(int) + eccKeyLengthInApvInt + sizeof(int), nonceLengthInApvInt)];
    NSString *nonceString = [[NSString alloc] initWithData:nonceFromApv encoding:NSUTF8StringEncoding];
    XCTAssertNotNil(nonceString);
    XCTAssertEqualObjects(nonceString, expectedNonce);
}


- (NSInteger)convertHexBytesToInt:(NSData *)data
{
    const uint8_t *bytes = [data bytes];
    NSUInteger length = [data length];
    NSInteger result = 0;

    for (NSUInteger i = 0; i < length; i++) {
        result = (result << 8) | bytes[i];
    }

    return result;
}

- (SecKeyRef)testPrivateKey
{
    NSDictionary *keyDictionary = @{
        @"x" : @"-lFEMga2N71Rwi-hDXpFRy02K4ArKGMHbd4Fp0radBo",
        @"y" : @"s3JmKxqfxRHpcT0uOBY1QH4IiumqK38h1WsIkKgJVGE",
        @"d" : @"5KMFrhYGTB3XQ5AEoo39IP0O_ExpMJ6AgY5QC9Cr1rQ",
        @"kid" : @"some-kid",
        @"kty" : @"EC",
        @"crv" : @"P-256"};
    const unsigned char bytes[] = {0x04};
    NSMutableData *keyData = [[NSMutableData alloc] initWithBytes:bytes length:sizeof(bytes)];
    [keyData appendData:[NSData msidDataFromBase64UrlEncodedString:keyDictionary[@"x"]]];
    [keyData appendData:[NSData msidDataFromBase64UrlEncodedString:keyDictionary[@"y"]]];
    [keyData appendData:[NSData msidDataFromBase64UrlEncodedString:keyDictionary[@"d"]]];
    
    NSDictionary *options = @{(id)kSecAttrKeyType: (id)kSecAttrKeyTypeECSECPrimeRandom,
                              (id)kSecAttrKeyClass: (id)kSecAttrKeyClassPrivate,
                              (id)kSecAttrKeySizeInBits: @256,
    };
    
    CFErrorRef cfError = NULL;
    SecKeyRef key = SecKeyCreateWithData((__bridge CFDataRef)keyData,
                                         (__bridge CFDictionaryRef)options,
                                         &cfError);
    return key;
}

@end
