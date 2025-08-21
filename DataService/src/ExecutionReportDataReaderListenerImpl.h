#pragma once

#include <memory>
#include <boost/lockfree/spsc_queue.hpp>
#include <SecurityListRequest.hpp>
#include <fastdds/dds/subscriber/DataReaderListener.hpp>

#include "OrderMassStatusRequestService.h"


namespace DistributedATS {

class ExecutionReportDataReaderListenerImpl : public eprosima::fastdds::dds::DataReaderListener
{
public:

    ~ExecutionReportDataReaderListenerImpl() override;

	ExecutionReportDataReaderListenerImpl( ExecutionReportsPtr& execution_reports )
		: _execution_reports(execution_reports) {};

    void on_data_available( eprosima::fastdds::dds::DataReader* reader ) override;


private:
    ExecutionReportsPtr _execution_reports;

};

} /* namespace FIXGateway */
