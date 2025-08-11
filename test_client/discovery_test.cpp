// discovery_network_test.cpp
#include <iostream>
#include <thread>
#include <chrono>
#include <fastdds/dds/domain/DomainParticipantFactory.hpp>
#include <fastdds/dds/domain/DomainParticipant.hpp>
#include <fastdds/dds/domain/qos/DomainParticipantQos.hpp>
#include <fastdds/dds/rtps/transport/UDPv4TransportDescriptor.h>
#include <fastdds/rtps/transport/TCPv4TransportDescriptor.h>

using namespace eprosima::fastdds::dds;
using namespace eprosima::fastdds::rtps;

int main()
{
    std::cout << "=== Network-Specific Discovery Test ===" << std::endl;
    std::cout << "Environment: " << getenv("PWD") << std::endl;
    std::cout << "Hostname: ";
    system("hostname");
    
    // Show network interfaces
    std::cout << "\nNetwork Interfaces:" << std::endl;
    system("ifconfig | grep -E '(inet |inet6)' | head -10");
    
    // Create participant with explicit network configuration
    DomainParticipantQos pqos = PARTICIPANT_QOS_DEFAULT;
    
    // Clear default transports and add specific UDP transport
    pqos.transport().use_builtin_transports = false;
    
    // Create UDP transport for localhost/local network
    auto udp_transport = std::make_shared<UDPv4TransportDescriptor>();
    udp_transport->sendBufferSize = 65536;
    udp_transport->receiveBufferSize = 65536;
    udp_transport->maxMessageSize = 65536;
    
    // Bind to all local interfaces (comment out for specific interface)
    // udp_transport->interfaceWhiteList.push_back("192.168.1.100"); // Replace with your IP
    
    pqos.transport().user_transports.push_back(udp_transport);
    
    // Set participant name for identification
    pqos.name("NETWORK_TEST_CLIENT");
    
    std::cout << "\nCreating participant with network configuration..." << std::endl;
    
    DomainParticipant* participant = DomainParticipantFactory::get_instance()->create_participant(
        0, pqos);
    
    if (participant == nullptr) {
        std::cerr << "❌ Failed to create participant!" << std::endl;
        return -1;
    }
    std::cout << "✅ Participant created successfully" << std::endl;
    
    // Extended discovery wait with progress
    std::cout << "\n⏳ Waiting 60 seconds for discovery..." << std::endl;
    for (int i = 0; i < 60; i++) {
        std::this_thread::sleep_for(std::chrono::seconds(1));
        
        std::vector<InstanceHandle_t> handles;
        participant->get_discovered_participants(handles);
        
        if (handles.size() > 0) {
            std::cout << "\n🎉 Discovered " << handles.size() << " participants!" << std::endl;
            
            // Get detailed participant info
            for (const auto& handle : handles) {
                builtin::ParticipantBuiltinTopicData pdata;
                if (participant->get_discovered_participant_data(pdata, handle) == ReturnCode_t::RETCODE_OK) {
                    std::cout << "  - Found: " << pdata.participant_name.name() << std::endl;
                    
                    // Check for MatchingEngine
                    if (pdata.participant_name.name().find("MatchingEngine") != std::string::npos ||
                        pdata.participant_name.name().find("MATCHING") != std::string::npos) {
                        std::cout << "  ✅ FOUND MATCHING ENGINE!" << std::endl;
                    }
                }
            }
            break;
        } else if (i % 10 == 0) {
            std::cout << "\n" << i << "s: Still discovering..." << std::flush;
        } else {
            std::cout << "." << std::flush;
        }
    }
    
    std::cout << "\n\nFinal discovery count: ";
    std::vector<InstanceHandle_t> final_handles;
    participant->get_discovered_participants(final_handles);
    std::cout << final_handles.size() << " participants" << std::endl;
    
    // Cleanup
    DomainParticipantFactory::get_instance()->delete_participant(participant);
    
    if (final_handles.size() == 0) {
        std::cout << "\n❌ NO PARTICIPANTS DISCOVERED" << std::endl;
        std::cout << "This indicates a network isolation issue." << std::endl;
        std::cout << "\nTroubleshooting steps:" << std::endl;
        std::cout << "1. Check if MatchingEngine is actually running" << std::endl;
        std::cout << "2. Verify both are on same network" << std::endl;
        std::cout << "3. Check firewall settings" << std::endl;
        std::cout << "4. Try running from same directory as MatchingEngine" << std::endl;
    }
    
    return 0;
}
