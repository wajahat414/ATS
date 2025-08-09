// test_new_order_fixed.cpp
#include <iostream>
#include <thread>
#include <chrono>
#include <fastdds/dds/domain/DomainParticipantFactory.hpp>
#include <fastdds/dds/domain/DomainParticipant.hpp>
#include <fastdds/dds/topic/TypeSupport.hpp>
#include <fastdds/dds/publisher/Publisher.hpp>
#include <fastdds/dds/publisher/DataWriter.hpp>
#include <fastdds/dds/publisher/DataWriterListener.hpp>
#include <fastdds/dds/domain/DomainParticipantListener.hpp>
// Include the generated types
#include "NewOrderSinglePubSubTypes.hpp"
#include "NewOrderSingle.hpp"

using namespace eprosima::fastdds::dds;

class TestListener : public DataWriterListener
{
public:
    void on_publication_matched(
        DataWriter *writer,
        const PublicationMatchedStatus &info) override
    {
        std::cout << "*** PUBLICATION MATCHED! Readers: " << info.current_count << " ***" << std::endl;
        matched_ = (info.current_count > 0);
    }

    bool matched_ = false;
};

class DetailedListener : public DataWriterListener, public DomainParticipantListener
{
public:
    void on_publication_matched(DataWriter *writer, const PublicationMatchedStatus &info) override
    {
        std::cout << "*** PUBLICATION MATCHED! Readers: " << info.current_count << " ***" << std::endl;
        matched_ = (info.current_count > 0);
    }

    bool matched_ = false;
};

int main()
{
    std::cout << "Starting Fixed NewOrderSingle Test..." << std::endl;

    // Create participant
    DomainParticipant *participant = DomainParticipantFactory::get_instance()->create_participant(
        0, PARTICIPANT_QOS_DEFAULT);

    if (participant == nullptr)
    {
        std::cerr << "Failed to create participant!" << std::endl;
        return -1;
    }
    std::cout << "✅ Participant created successfully" << std::endl;

    // Register type with FULL type name
    TypeSupport type_support(new DistributedATS_NewOrderSingle::NewOrderSinglePubSubType());

    // The type name should be the full namespace name
    std::string type_name = "DistributedATS_NewOrderSingle::NewOrderSingle";
    std::cout << "Using type name: " << type_name << std::endl;

    // Register the type with explicit name
    if (type_support.register_type(participant, type_name) != eprosima::fastdds::dds::RETCODE_OK)
    {
        std::cerr << "Failed to register type!" << std::endl;
        return -1;
    }
    std::cout << "✅ Type registered successfully" << std::endl;

    // Create topic using the full type name
    Topic *topic = participant->create_topic(
        "NEW_ORDER_SINGLE_TOPIC", // Topic name - verify this matches exactly
        type_name,                // Full type name
        TOPIC_QOS_DEFAULT);

    if (topic == nullptr)
    {
        std::cerr << "Failed to create topic!" << std::endl;
        return -1;
    }
    std::cout << "✅ Topic created successfully" << std::endl;

    // Create publisher
    Publisher *publisher = participant->create_publisher(PUBLISHER_QOS_DEFAULT);
    if (publisher == nullptr)
    {
        std::cerr << "Failed to create publisher!" << std::endl;
        return -1;
    }
    std::cout << "✅ Publisher created successfully" << std::endl;

    // Create data writer with listener
    TestListener listener;
    DataWriter *writer = publisher->create_datawriter(topic, DATAWRITER_QOS_DEFAULT, &listener);
    if (writer == nullptr)
    {
        std::cerr << "Failed to create data writer!" << std::endl;
        return -1;
    }
    std::cout << "✅ DataWriter created successfully" << std::endl;

    std::cout << "\nWaiting for MatchingEngine to be discovered..." << std::endl;

    // Wait for discovery with shorter timeout
    int wait_count = 0;
    while (!listener.matched_ && wait_count < 10)
    { // Reduced to 10 seconds
        std::this_thread::sleep_for(std::chrono::seconds(1));
        std::cout << "Waiting... (" << ++wait_count << "/10)" << std::endl;
    }

    if (!listener.matched_)
    {
        std::cerr << "⚠️  No subscribers found - check topic name and type!" << std::endl;
        std::cout << "Sending message anyway..." << std::endl;
    }
    else
    {
        std::cout << "✅ MatchingEngine discovered! Sending test order..." << std::endl;
    }

    // Create and populate the test message - EXACT copy from working LatencyTest
    DistributedATS_NewOrderSingle::NewOrderSingle testOrder;

    // Set routing fields (CRITICAL for MatchingEngine filter)
    testOrder.DATS_Source("TEST_CLIENT");
    testOrder.DATS_Destination("MATCHING_ENGINE"); // Filter requirement
    testOrder.DATS_SourceUser("TEST_USER");
    testOrder.DATS_DestinationUser("DATA_SERVICE_A"); // Must match DataService name

    // Set order fields with EXPLICIT values
    testOrder.ClOrdID("TEST_ORDER_001");
    testOrder.Symbol("BTC-USD");
    testOrder.SecurityExchange("BTC_MARKET"); // Filter requirement
    testOrder.Side(1);                        // EXPLICIT: 1=Buy
    testOrder.OrderQty(10);
    testOrder.Price(10050.0); // EXPLICIT: double
    testOrder.OrdType(2);     // EXPLICIT: 2=Limit
    testOrder.TimeInForce(1); // EXPLICIT: 1=GTC

    // Set FIX header fields
    testOrder.fix_header().BeginString("FIX.4.4");
    testOrder.fix_header().MsgType("D");
    testOrder.fix_header().SenderCompID("TEST_CLIENT");
    testOrder.fix_header().TargetCompID("MATCHING_ENGINE");
    testOrder.fix_header().SendingTime(std::chrono::duration_cast<std::chrono::microseconds>(
                                           std::chrono::system_clock::now().time_since_epoch())
                                           .count());

    // Print the message we're sending
    std::cout << "\n=== Sending Fixed Test Message ===" << std::endl;
    std::cout << "DATS_Source: " << testOrder.DATS_Source() << std::endl;
    std::cout << "DATS_Destination: " << testOrder.DATS_Destination() << std::endl;
    std::cout << "DATS_SourceUser: " << testOrder.DATS_SourceUser() << std::endl;
    std::cout << "DATS_DestinationUser: " << testOrder.DATS_DestinationUser() << std::endl;
    std::cout << "SecurityExchange: " << testOrder.SecurityExchange() << std::endl;
    std::cout << "Symbol: " << testOrder.Symbol() << std::endl;
    std::cout << "ClOrdID: " << testOrder.ClOrdID() << std::endl;
    std::cout << "Side: " << testOrder.Side() << std::endl; // Should show 1
    std::cout << "Qty: " << testOrder.OrderQty() << std::endl;
    std::cout << "Price: " << testOrder.Price() << std::endl;
    std::cout << "OrdType: " << testOrder.OrdType() << std::endl;
    std::cout << "TimeInForce: " << testOrder.TimeInForce() << std::endl;

    // Send the message multiple times to ensure delivery
    for (int i = 0; i < 3; i++)
    {
        ReturnCode_t result = writer->write(&testOrder);
        if (result == eprosima::fastdds::dds::RETCODE_OK)
        {
            std::cout << "\n✅ Message " << (i + 1) << " sent successfully!" << std::endl;
        }
        else
        {
            std::cout << "\n❌ Failed to send message " << (i + 1) << "! Error code: " << (int)result << std::endl;
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(100));
    }

    std::cout << "\n🔍 Now check MatchingEngine logs for 'Kuddos New Order Recieved'" << std::endl;
    std::cout << "The 'new order' entry in logs suggests message was received!" << std::endl;
    std::cout << "\nPress Enter to exit..." << std::endl;
    std::cin.get();

    // Cleanup
    participant->delete_contained_entities();
    DomainParticipantFactory::get_instance()->delete_participant(participant);

    return 0;
}
