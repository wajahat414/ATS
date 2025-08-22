import argparse
import json
import threading
import time

from typing import List

try:
    from kafka import KafkaProducer, KafkaConsumer
except ImportError as e:
    raise SystemExit(f"Kafka import failed: {e}")


def print_json(obj):
    print(json.dumps(obj, indent=2))


def make_order_payload(
    user_token: str,
    exchange: str,
    symbol: str,
    side: str,
    qty: int,
    price: int,
    ordtype: str,
    tif: str,
) -> dict:
    return {
        "instrument": {
            "security_exchange": exchange,
            "symbol": symbol,
        },
        "user_token": user_token,
        "new_order_single": {
            "side": side,  # "1"=Buy, "2"=Sell
            "order_qty": qty,
            "price": price,
            "order_type": ordtype,  # "1"=Market, "2"=Limit
            "time_in_force": tif,  # "0"=Day
        },
    }


def start_consumer(brokers: List[str], topic: str, group_id: str, stop_after: int):
    consumer = KafkaConsumer(
        topic,
        bootstrap_servers=brokers,
        group_id=group_id,
        enable_auto_commit=True,
        auto_offset_reset="latest",
        value_deserializer=lambda v: json.loads(v.decode("utf-8")),
    )

    start = time.time()
    print(
        f"[consumer] Listening on topic='{topic}' brokers={brokers} group_id='{group_id}'"
    )
    try:
        for msg in consumer:
            print("[consumer] execution_report:")
            print_json(msg.value)
            if stop_after > 0 and (time.time() - start) >= stop_after:
                print("[consumer] Time limit reached, stopping consumer.")
                break
    finally:
        consumer.close()


def send_order(brokers: List[str], topic: str, payload: dict):
    producer = KafkaProducer(
        bootstrap_servers=brokers,
        value_serializer=lambda v: json.dumps(v).encode("utf-8"),
        linger_ms=10,
        acks="all",
    )
    print(f"[producer] Sending to topic='{topic}' brokers={brokers}")
    print("[producer] order payload:")
    print_json(payload)
    fut = producer.send(topic, payload)
    metadata = fut.get(timeout=10)
    print(f"[producer] sent partition={metadata.partition} offset={metadata.offset}")
    producer.flush()
    producer.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Kafka test client: send new order and listen for execution reports"
    )
    parser.add_argument(
        "--brokers", default="localhost:9092", help="Comma-separated Kafka brokers"
    )
    parser.add_argument(
        "--orders-topic", default="new_orders", help="Topic to send new orders"
    )
    parser.add_argument(
        "--exec-topic",
        default="execution_report",
        help="Topic to consume execution reports",
    )
    parser.add_argument(
        "--group-id",
        default="python-kafka-client",
        help="Consumer group id for execution reports",
    )
    parser.add_argument(
        "--user-token",
        default="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VybmFtZSI6ImludmVzdG9yXzIifQ.Bpnm03NeJU_tblzFTqxCpRxUm6K757nSpXkiLaA_UZ4",
        help="Investor token key",
    )
    parser.add_argument("--exchange", default="BTC_MARKET", help="Security exchange")
    parser.add_argument("--symbol", default="BTC-CNY", help="Instrument symbol")
    parser.add_argument("--side", default="1", choices=["1", "2"], help="1=Buy, 2=Sell")
    parser.add_argument("--qty", type=int, default=100, help="Order quantity")
    parser.add_argument("--price", type=int, default=40100, help="Price (integer)")
    parser.add_argument(
        "--ordtype", default="2", choices=["1", "2"], help="1=Market, 2=Limit"
    )
    parser.add_argument("--tif", default="0", help="Time in force, 0=Day")
    parser.add_argument(
        "--consume-seconds",
        type=int,
        default=60,
        help="Seconds to keep consuming before exit",
    )

    args = parser.parse_args()

    brokers = [b.strip() for b in args.brokers.split(",") if b.strip()]

    # Start consumer thread first so we don't miss messages
    consumer_thread = threading.Thread(
        target=start_consumer,
        args=(brokers, args.exec_topic, args.group_id, args.consume_seconds),
        daemon=True,
    )
    consumer_thread.start()

    # Give consumer a brief moment to join the group
    time.sleep(1)

    # Build and send order
    payload = make_order_payload(
        user_token=args.user_token,
        exchange=args.exchange,
        symbol=args.symbol,
        side=args.side,
        qty=args.qty,
        price=args.price,
        ordtype=args.ordtype,
        tif=args.tif,
    )
    send_order(brokers, args.orders_topic, payload)

    # Keep main alive while consumer prints reports
    try:
        consumer_thread.join(timeout=args.consume_seconds + 5)
    except KeyboardInterrupt:
        pass
