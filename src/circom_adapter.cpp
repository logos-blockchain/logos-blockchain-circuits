#include "circom_adapter.hpp"
#include "circom_fwd.hpp"

#include <vector>
#include <sstream>
#include <stdexcept>

Circom_Circuit* loadCircuit(const ConstBytes& circuit_bytes) {
    Circom_Circuit* circuit = new Circom_Circuit;

    circuit->InputHashMap = new HashSignalInfo[get_size_of_input_hashmap()];
    uint dsize = get_size_of_input_hashmap() * sizeof(HashSignalInfo);
    memcpy((void*)(circuit->InputHashMap), (void*)circuit_bytes.data, dsize);

    circuit->witness2SignalList = new u64[get_size_of_witness()];
    uint inisize = dsize;
    dsize = get_size_of_witness() * sizeof(u64);
    memcpy((void*)(circuit->witness2SignalList), (void*)(circuit_bytes.data + inisize), dsize);

    circuit->circuitConstants = new FrElement[get_size_of_constants()];
    if (get_size_of_constants() > 0) {
        inisize += dsize;
        dsize = get_size_of_constants() * sizeof(FrElement);
        memcpy((void*)(circuit->circuitConstants), (void*)(circuit_bytes.data + inisize), dsize);
    }

    std::map<u32, IOFieldDefPair> templateInsId2IOSignalInfo1;
    IOFieldDefPair* busInsId2FieldInfo1 = nullptr;
    if (get_size_of_io_map() > 0) {
        u32 index[get_size_of_io_map()];
        inisize += dsize;
        dsize = get_size_of_io_map() * sizeof(u32);
        memcpy((void*)index, (void*)(circuit_bytes.data + inisize), dsize);
        inisize += dsize;
        assert(inisize % sizeof(u32) == 0);
        assert(circuit_bytes.size % sizeof(u32) == 0);
        u32 dataiomap[(circuit_bytes.size - inisize) / sizeof(u32)];
        memcpy((void*)dataiomap, (void*)(circuit_bytes.data + inisize), circuit_bytes.size - inisize);
        u32* pu32 = dataiomap;
        for (int i = 0; i < get_size_of_io_map(); i++) {
            u32 n = *pu32;
            IOFieldDefPair p;
            p.len = n;
            IOFieldDef defs[n];
            pu32 += 1;
            for (u32 j = 0; j < n; j++) {
                defs[j].offset = *pu32;
                u32 len = *(pu32 + 1);
                defs[j].len = len;
                defs[j].lengths = new u32[len];
                memcpy((void*)defs[j].lengths, (void*)(pu32 + 2), len * sizeof(u32));
                pu32 += len + 2;
                defs[j].size = *pu32;
                defs[j].busId = *(pu32 + 1);
                pu32 += 2;
            }
            p.defs = (IOFieldDef*)calloc(p.len, sizeof(IOFieldDef));
            for (u32 j = 0; j < p.len; j++) {
                p.defs[j] = defs[j];
            }
            templateInsId2IOSignalInfo1[index[i]] = p;
        }
        busInsId2FieldInfo1 = (IOFieldDefPair*)calloc(get_size_of_bus_field_map(), sizeof(IOFieldDefPair));
        for (int i = 0; i < get_size_of_bus_field_map(); i++) {
            u32 n = *pu32;
            IOFieldDefPair p;
            p.len = n;
            IOFieldDef defs[n];
            pu32 += 1;
            for (u32 j = 0; j < n; j++) {
                defs[j].offset = *pu32;
                u32 len = *(pu32 + 1);
                defs[j].len = len;
                defs[j].lengths = new u32[len];
                memcpy((void*)defs[j].lengths, (void*)(pu32 + 2), len * sizeof(u32));
                pu32 += len + 2;
                defs[j].size = *pu32;
                defs[j].busId = *(pu32 + 1);
                pu32 += 2;
            }
            p.defs = (IOFieldDef*)calloc(10, sizeof(IOFieldDef));
            for (u32 j = 0; j < p.len; j++) {
                p.defs[j] = defs[j];
            }
            busInsId2FieldInfo1[i] = p;
        }
    }
    circuit->templateInsId2IOSignalInfo = move(templateInsId2IOSignalInfo1);
    circuit->busInsId2FieldInfo = busInsId2FieldInfo1;

    return circuit;
}

void loadJson(Circom_CalcWit *ctx, const char* inputs_json) {
    json jin = json::parse(inputs_json);
    json j;

    //std::cout << jin << std::endl;
    std::string prefix = "";
    qualify_input(prefix, jin, j);
    //std::cout << j << std::endl;

    u64 nItems = j.size();
    // printf("Items : %llu\n",nItems);
    if (nItems == 0){
        ctx->tryRunCircuit();
    }
    for (json::iterator it = j.begin(); it != j.end(); ++it) {
        // std::cout << it.key() << " => " << it.value() << '\n';
        u64 h = fnv1a(it.key());
        std::vector<FrElement> v;
        json2FrElements(it.value(),v);
        uint signalSize = ctx->getInputSignalSize(h);
        if (v.size() < signalSize) {
            std::ostringstream errStrStream;
            errStrStream << "Error loading signal " << it.key() << ": Not enough values\n";
            throw std::runtime_error(errStrStream.str() );
        }
        if (v.size() > signalSize) {
            std::ostringstream errStrStream;
            errStrStream << "Error loading signal " << it.key() << ": Too many values\n";
            throw std::runtime_error(errStrStream.str() );
        }
        for (uint i = 0; i<v.size(); i++){
            try {
                // std::cout << it.key() << "," << i << " => " << Fr_element2str(&(v[i])) << '\n';
                ctx->setInputSignal(h,i,v[i]);
            } catch (std::runtime_error e) {
                std::ostringstream errStrStream;
                errStrStream << "Error setting signal: " << it.key() << "\n" << e.what();
                throw std::runtime_error(errStrStream.str() );
            }
        }
    }
}

void writeBinWitness(Circom_CalcWit *ctx, Bytes* output_witness) {
    std::vector<uint8_t> buf;

    auto write = [&](const void* data, size_t size) {
        const uint8_t* p = (const uint8_t*)data;
        buf.insert(buf.end(), p, p + size);
    };

    write("wtns", 4);

    u32 version = 2;
    write(&version, 4);

    u32 nSections = 2;
    write(&nSections, 4);

    // Header
    u32 idSection1 = 1;
    write(&idSection1, 4);

    u32 n8 = Fr_N64*8;

    u64 idSection1length = 8 + n8;
    write(&idSection1length, 8);

    write(&n8, 4);

    write(Fr_q.longVal, Fr_N64*8);

    uint Nwtns = get_size_of_witness();

    u32 nVars = (u32)Nwtns;
    write(&nVars, 4);

    // Data
    u32 idSection2 = 2;
    write(&idSection2, 4);

    u64 idSection2length = (u64)n8*(u64)Nwtns;
    write(&idSection2length, 8);

    FrElement v;

    for (int i=0;i<Nwtns;i++) {
        ctx->getWitness(i, &v);
        Fr_toLongNormal(&v, &v);
        write(v.longVal, Fr_N64*8);
    }

    size_t size = buf.size();
    output_witness->data = static_cast<uint8_t*>(malloc(size));
    if (output_witness->data == nullptr) return;
    output_witness->size = size;
    memcpy(output_witness->data, buf.data(), size);
}
