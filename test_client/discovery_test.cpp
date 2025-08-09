// simple_discovery_test.cpp
#include <iostream>
#include <thread>
#include <chrono>
#include <fastdds/dds/domain/DomainParticipantFactory.hpp>
#include <fastdds/dds/domain/DomainParticipant.hpp>
#include <fastdds/dds/log/Log.hpp>

using namespace eprosima::fastdds::dds;

int main()
{
    eprosima::fastdds::dds::Log::SetVerbosity(eprosima::fastdds::dds::Log::Kind::Info);
    eprosima::fastdds::dds::Log::SetCategoryFilter(std::regex("(RTPS|DISCOVERY)"));

    std::cout << "=== Simple Discovery Test ===" << std::endl;
    std::cout << "Environment: " << getenv("PWD") << std::endl;
    std::cout << "Hostname: ";
    system("hostname");

    auto participant = DomainParticipantFactory::get_instance()->create_participant(0, PARTICIPANT_QOS_DEFAULT);

    if (participant)
    {
        std::cout << "✅ Participant created successfully" << std::endl;

        std::this_thread::sleep_for(std::chrono::seconds(10));

        std::vector<InstanceHandle_t> handles;
        participant->get_discovered_participants(handles);
        std::cout << "Discovered " << handles.size() << " other participants" << std::endl;

        DomainParticipantFactory::get_instance()->delete_participant(participant);
    }
    else
    {
        std::cout << "❌ Failed to create participant" << std::endl;
    }

    return 0;
}
