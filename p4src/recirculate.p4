#include <core.p4>
#if __TARGET_TOFINO__ == 3
#include <t3na.p4>
#elif __TARGET_TOFINO__ == 2
#include <t2na.p4>
#else
#include <tna.p4>
#endif

const bit<16> TYPE_REC = 0x1212;
const bit<16> TYPE_IPV4 = 0x800;
const PortId_t rec_port = 68;       // recirculation port

#include "common/headers.p4"
#include "common/util.p4"

header rec_h {
    bit<16> proto_id;
    bit<16> rec_num; // switch needs to recirculate the packet rec_num times
}

struct headers {
    ethernet_h   ethernet;
    rec_h        rec;
    ipv4_h       ipv4;
}

struct metadata_t {}

// ---------------------------------------------------------------------------
// Ingress parser
// ---------------------------------------------------------------------------
parser SwitchIngressParser(
        packet_in pkt,
        out headers hdr,
        out metadata_t ig_md,
        out ingress_intrinsic_metadata_t ig_intr_md) {

    TofinoIngressParser() tofino_parser;

    state start {
        tofino_parser.apply(pkt, ig_intr_md);
        transition parse_ethernet;
    }

    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        transition select (hdr.ethernet.ether_type) {
            TYPE_REC : parse_rec;
            TYPE_IPV4 : parse_ipv4;
            default : reject;
        }
    }

    state parse_rec {
        pkt.extract(hdr.rec);
        transition select (hdr.rec.proto_id) {
            TYPE_IPV4 : parse_ipv4;
            default : reject;
        }
    }

    state parse_ipv4 {
        pkt.extract(hdr.ipv4);
        transition accept;
    }
}

// ---------------------------------------------------------------------------
// Ingress Deparser
// ---------------------------------------------------------------------------
control SwitchIngressDeparser(
        packet_out pkt,
        inout headers hdr,
        in metadata_t ig_md,
        in ingress_intrinsic_metadata_for_deparser_t ig_intr_dprsr_md) {

    apply {
        pkt.emit(hdr);
    }
}

control SwitchIngress(
        inout headers hdr,
        inout metadata_t ig_md,
        in ingress_intrinsic_metadata_t ig_intr_md,
        in ingress_intrinsic_metadata_from_parser_t ig_intr_prsr_md,
        inout ingress_intrinsic_metadata_for_deparser_t ig_intr_dprsr_md,
        inout ingress_intrinsic_metadata_for_tm_t ig_intr_tm_md) {

    action drop() {
        ig_intr_dprsr_md.drop_ctl = 0x1;
    }

    action send(PortId_t port) {
        ig_intr_tm_md.ucast_egress_port = port;
    }

    // Recirculate the packet to the recirculation port
    // Decrease the recirculation number
    action recirculate(PortId_t recirc_port){
        ig_intr_tm_md.ucast_egress_port = recirc_port;
        hdr.rec.rec_num = hdr.rec.rec_num - 1;      
    }

    table rec_num_table {
        key = {
            hdr.rec.rec_num : exact;
        }
        actions = {
            send;
            recirculate;
        }
        default_action = recirculate(rec_port);
    }

    apply {
        // if (hdr.rec.rec_num == 0) {
        //     send(1);
        // } else {
        //     recirculate(rec_port);
        // }

        rec_num_table.apply();

        // No need for egress processing, skip it and use empty controls for egress.
        ig_intr_tm_md.bypass_egress = 1;
    }

}

Pipeline(SwitchIngressParser(),
         SwitchIngress(),
         SwitchIngressDeparser(),
         EmptyEgressParser(),
         EmptyEgress(),
         EmptyEgressDeparser()) pipe;

Switch(pipe) main;