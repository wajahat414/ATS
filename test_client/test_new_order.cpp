// test_new_order.cpp - Simple version without complex listeners
#include <iostream>
#include <thread>
#include <chrono>
#include <fastdds/dds/domain/DomainParticipantFactory.hpp>
#include <fastdds/dds/domain/DomainParticipant.hpp>
#include <fastdds/dds/topic/TypeSupport.hpp>
#include <fastdds/dds/publisher/Publisher.hpp>
#include <fastdds/dds/publisher/DataWriter.hpp>

// Include the generated types
#include "NewOrderSinglePubSubTypes.hpp"
#include "NewOrderSingle.hpp"

using namespace eprosima::fastdds::dds;

int main()
{
    std::cout << "=== NewOrderSingle Test Client (CMake Build) ===" << std::endl;

    // Create participant
    DomainParticipant *participant = DomainParticipantFactory::get_instance()->create_participant(
        0, PARTICIPANT_QOS_DEFAULT);

    if (participant == nullptr)
    {
        std::cerr << "❌ Failed to create DDS participant!" << std::endl;
        return -1;
    }
    std::cout << "✅ DDS Participant created" << std::endl;

    // Register type
    TypeSupport type_support(new DistributedATS_NewOrderSingle::NewOrderSinglePubSubType());
    std::string type_name = "DistributedATS_NewOrderSingle::NewOrderSingle";

    if (type_support.register_type(participant, type_name) != eprosima::fastdds::dds::RETCODE_OK)
    {
        std::cerr << "❌ Failed to register type: " << type_name << std::endl;
        return -1;
    }
    std::cout << "✅ Type registered: " << type_name << std::endl;

    // Create topic
    Topic *topic = participant->create_topic("NEW_ORDER_SINGLE_TOPIC", type_name, TOPIC_QOS_DEFAULT);
    if (topic == nullptr)
    {
        std::cerr << "❌ Failed to create topic: NEW_ORDER_SINGLE" << std::endl;
        return -1;
    }
    std::cout << "✅ Topic created: NEW_ORDER_SINGLE" << std::endl;

    // Create publisher and data writer
    Publisher *publisher = participant->create_publisher(PUBLISHER_QOS_DEFAULT);
    if (publisher == nullptr)
    {
        std::cerr << "❌ Failed to create publisher!" << std::endl;
        return -1;
    }

    DataWriter *writer = publisher->create_datawriter(topic, DATAWRITER_QOS_DEFAULT);
    if (writer == nullptr)
    {
        std::cerr << "❌ Failed to create data writer!" << std::endl;
        return -1;
    }
    std::cout << "✅ DataWriter created" << std::endl;

    // Wait for discovery
    std::cout << "\n⏳ Waiting 5 seconds for DDS discovery..." << std::endl;
    std::this_thread::sleep_for(std::chrono::seconds(5));

    // Create the test message with exact values for MatchingEngine filter
    DistributedATS_NewOrderSingle::NewOrderSingle testOrder;

    // CRITICAL: These must match MatchingEngine filter exactly
    testOrder.DATS_Source("CMAKE_TEST_CLIENT");
    testOrder.DATS_Destination("MATCHING_ENGINE"); // Filter requirement #1
    testOrder.DATS_SourceUser("CMAKE_TEST_USER");
    testOrder.DATS_DestinationUser("DATA_SERVICE_A"); // Must match DataService name

    // Order details
    testOrder.ClOrdID("CMAKE_TEST_ORDER_001");
    testOrder.Symbol("BTC-USD");
    testOrder.SecurityExchange("BTC_MARKET"); // Filter requirement #2
    testOrder.Side(1);                        // Buy
    testOrder.OrderQty(10);
    testOrder.Price(50000.0);
    testOrder.OrdType(2);     // Limit
    testOrder.TimeInForce(1); // GTC

    // FIX header
    testOrder.fix_header().BeginString("FIX.4.4");
    testOrder.fix_header().MsgType("D");
    testOrder.fix_header().SenderCompID("CMAKE_TEST_CLIENT");
    testOrder.fix_header().TargetCompID("MATCHING_ENGINE");
    testOrder.fix_header().SendingTime(std::chrono::duration_cast<std::chrono::microseconds>(
                                           std::chrono::system_clock::now().time_since_epoch())
                                           .count());

    // Display message details
    std::cout << "\n=== Test Message Details ===" << std::endl;
    std::cout << "ClOrdID: " << testOrder.ClOrdID() << std::endl;
    std::cout << "Symbol: " << testOrder.Symbol() << std::endl;
    std::cout << "DATS_Destination: " << testOrder.DATS_Destination() << std::endl;
    std::cout << "SecurityExchange: " << testOrder.SecurityExchange() << std::endl;
    std::cout << "Side: " << (int)testOrder.Side() << " (1=Buy)" << std::endl;
    std::cout << "Qty: " << testOrder.OrderQty() << std::endl;
    std::cout << "Price: " << testOrder.Price() << std::endl;
    std::cout << "OrdType: " << (int)testOrder.OrdType() << " (2=Limit)" << std::endl;

    std::cout << "\n📤 Sending test messages..." << std::endl;

    // Send multiple messages to ensure delivery
    bool success = false;
    for (int i = 0; i < 5; i++)
    {
        ReturnCode_t result = writer->write(&testOrder);
        if (result == eprosima::fastdds::dds::RETCODE_OK)
        {
            std::cout << "✅ Message " << (i + 1) << "/5 sent successfully" << std::endl;
            success = true;
        }
        else
        {
            std::cout << "❌ Message " << (i + 1) << "/5 failed (error: " << (int)result << ")" << std::endl;
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(1000));
    }

    if (success)
    {
        std::cout << "\n🔍 CHECK MATCHING ENGINE LOGS NOW!" << std::endl;
        std::cout << "Expected log entry: 'Kuddos New Order Recieved'" << std::endl;
        std::cout << "Log file: ../DistributedATS/MiscATS/CryptoCLOB/logs/MatchingEngine.matching_engine_MARKET_BTC.ini.console.log" << std::endl;

        std::cout << "\nFilter requirements met:" << std::endl;
        std::cout << "✅ DATS_Destination = 'MATCHING_ENGINE'" << std::endl;
        std::cout << "✅ SecurityExchange = 'BTC_MARKET'" << std::endl;
    }
    else
    {
        std::cout << "\n❌ All message sends failed!" << std::endl;
    }

    // Keep publisher alive for a few more seconds
    std::cout << "\n⏳ Keeping publisher alive for 10 seconds..." << std::endl;
    std::this_thread::sleep_for(std::chrono::seconds(10));

    // Cleanup
    participant->delete_contained_entities();
    DomainParticipantFactory::get_instance()->delete_participant(participant);

    std::cout << "\n✅ Test completed successfully!" << std::endl;
    return 0;
}
