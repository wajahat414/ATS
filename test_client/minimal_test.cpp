// minimal_test.cpp
#include <iostream>
#include <DomainParticipant.hpp>
#include <fastdds/dds/domain/DomainParticipant.hpp>
#include <DomainParticipantFactory.hpp>
int main()
{
    std::cout << "Testing basic DDS functionality..." << std::endl;

    auto factory = eprosima::fastdds::dds::DomainParticipantFactory::get_instance();
    if (factory != nullptr)
    {
        std::cout << "✅ DDS Factory created successfully" << std::endl;

        auto participant = factory->create_participant(0, eprosima::fastdds::dds::PARTICIPANT_QOS_DEFAULT);
        if (participant != nullptr)
        {
            std::cout << "✅ DDS Participant created successfully" << std::endl;

            // Clean up
            factory->delete_participant(participant);
            std::cout << "✅ Basic DDS test passed!" << std::endl;
            return 0;
        }
        else
        {
            std::cout << "❌ Failed to create participant" << std::endl;
        }
    }
    else
    {
        std::cout << "❌ Failed to get DDS factory" << std::endl;
    }

    return -1;
}
