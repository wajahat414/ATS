import argparse
import json
import threading
import time
import uuid
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Dict, Tuple, List

try:
    import requests
except ImportError as e:
    raise SystemExit(f"requests is required: {e}")


def build_payload(
    side: int,
    cl_id: str,
    symbol: str,
    exchange: str,
    qty: int,
    price: int,
    ord_type: int,
    tif: int,
    user_id: int,
    user_uuid: str,
    leverage: float,
    tp: float,
    sl: float,
    stop_px: int,
) -> Dict:
    return {
        "instrument": {"symbol": symbol, "security_exchange": exchange},
        "new_order_single": {
            "side": side,
            "ord_type": ord_type,
            "order_qty": qty,
            "time_in_force": tif,
            "price": price,
            "stop_px": stop_px,
            "cl_ord_id": cl_id,
        },
        "user_id": user_id,
        "user_uuid": user_uuid,
        "leverage": leverage,
        "take_profit_price": tp,
        "stop_loss_price": sl,
    }


def post_order(
    session: requests.Session, url: str, payload: Dict, timeout: float
) -> Tuple[bool, float, int, str]:
    t0 = time.perf_counter()
    try:
        resp = session.post(url, json=payload, timeout=timeout)
        dt = time.perf_counter() - t0
        ok = 200 <= resp.status_code < 300
        return ok, dt, resp.status_code, (resp.text[:200] if not ok else "")
    except Exception as e:
        dt = time.perf_counter() - t0
        return False, dt, -1, str(e)


def run_phase(
    name: str,
    url: str,
    total: int,
    side: int,
    session: requests.Session,
    concurrency: int,
    timeout: float,
    symbol: str,
    exchange: str,
    qty: int,
    price: int,
    ord_type: int,
    tif: int,
    user_id: int,
    user_uuid: str,
    leverage: float,
    tp: float,
    sl: float,
    stop_px: int,
) -> Dict:
    print(
        f"[phase {name}] sending {total} orders side={side} price={price} qty={qty} with concurrency={concurrency}"
    )
    successes: int = 0
    failures: int = 0
    lats: List[float] = []
    err_samples: List[str] = []
    status_counts: Dict[int, int] = {}

    lock = threading.Lock()

    def submit_one(i: int):
        cl_id = f"client-{name}-{i}-{uuid.uuid4().hex[:8]}"
        payload = build_payload(
            side,
            cl_id,
            symbol,
            exchange,
            qty,
            price,
            ord_type,
            tif,
            user_id,
            user_uuid,
            leverage,
            tp,
            sl,
            stop_px,
        )
        ok, dt, status, err = post_order(session, url, payload, timeout)
        with lock:
            lats.append(dt)
            status_counts[status] = status_counts.get(status, 0) + 1
            if ok:
                nonlocal successes
                successes += 1
            else:
                nonlocal failures
                failures += 1
                if len(err_samples) < 5:
                    err_samples.append(f"status={status} err={err}")

    start = time.perf_counter()
    with ThreadPoolExecutor(max_workers(concurrency)) as exe:
        futures = [exe.submit(submit_one, i) for i in range(total)]
        for _ in as_completed(futures):
            pass
    elapsed = time.perf_counter() - start

    lats.sort()
    p50 = lats[int(0.50 * len(lats))] if lats else 0
    p95 = lats[int(0.95 * len(lats))] if lats else 0
    p99 = lats[int(0.99 * len(lats))] if lats else 0

    print(
        f"[phase {name}] done in {elapsed:.2f}s | succ={successes} fail={failures} | p50={p50:.3f}s p95={p95:.3f}s p99={p99:.3f}s | rps={total/elapsed if elapsed>0 else 0:.1f}"
    )
    if err_samples:
        print(f"[phase {name}] sample errors:")
        for e in err_samples:
            print("  ", e)
    return {
        "name": name,
        "success": successes,
        "fail": failures,
        "elapsed": elapsed,
        "status_counts": status_counts,
        "p50": p50,
        "p95": p95,
        "p99": p99,
    }


def max_workers(c: int) -> int:
    return max(1, int(c))


def main():
    ap = argparse.ArgumentParser(
        description="Simple REST load test: 10k buys then 10k sells"
    )
    ap.add_argument(
        "--url",
        default="http://127.0.0.1:4500/api/v1/orders",
        help="Orders REST endpoint",
    )
    ap.add_argument("--buys", type=int, default=10000, help="Number of buy orders")
    ap.add_argument("--sells", type=int, default=10000, help="Number of sell orders")
    ap.add_argument("--concurrency", type=int, default=200, help="Concurrent workers")
    ap.add_argument(
        "--timeout", type=float, default=5.0, help="Per-request timeout seconds"
    )
    ap.add_argument("--symbol", default="BTCUSD", help="Instrument symbol")
    ap.add_argument("--exchange", default="BTC_MARKET", help="Security exchange")
    ap.add_argument("--qty", type=int, default=100, help="Order quantity")
    ap.add_argument("--price", type=int, default=110000, help="Order price")
    ap.add_argument("--ordtype", type=int, default=2, help="OrdType (1=Market,2=Limit)")
    ap.add_argument("--tif", type=int, default=0, help="TimeInForce (0=Day)")
    ap.add_argument(
        "--stop-px",
        type=int,
        default=90000,
        help="Stop price for stop/stop-limit orders",
    )
    ap.add_argument("--user-id", type=int, default=42, help="User ID")
    ap.add_argument(
        "--user-uuid", default="01234567-89ab-cdef-0123-456789abcdef", help="User UUID"
    )
    ap.add_argument("--leverage", type=float, default=10.0, help="Leverage")
    ap.add_argument(
        "--take-profit", type=float, default=1.13000, help="Take profit price"
    )
    ap.add_argument("--stop-loss", type=float, default=1.11000, help="Stop loss price")
    args = ap.parse_args()

    session = requests.Session()
    adapter = requests.adapters.HTTPAdapter(
        pool_connections=args.concurrency, pool_maxsize=args.concurrency
    )
    session.mount("http://", adapter)
    session.mount("https://", adapter)
    session.headers.update({"Content-Type": "application/json"})

    overall_start = time.perf_counter()
    res1 = run_phase(
        name="BUY",
        url=args.url,
        total=args.buys,
        side=1,
        session=session,
        concurrency=args.concurrency,
        timeout=args.timeout,
        symbol=args.symbol,
        exchange=args.exchange,
        qty=args.qty,
        price=args.price,
        ord_type=args.ordtype,
        tif=args.tif,
        user_id=args.user_id,
        user_uuid=args.user_uuid,
        leverage=args.leverage,
        tp=args.take_profit,
        sl=args.stop_loss,
        stop_px=args.stop_px,
    )

    res2 = run_phase(
        name="SELL",
        url=args.url,
        total=args.sells,
        side=2,
        session=session,
        concurrency=args.concurrency,
        timeout=args.timeout,
        symbol=args.symbol,
        exchange=args.exchange,
        qty=args.qty,
        price=args.price,
        ord_type=args.ordtype,
        tif=args.tif,
        user_id=args.user_id,
        user_uuid=args.user_uuid,
        leverage=args.leverage,
        tp=args.take_profit,
        sl=args.stop_loss,
        stop_px=args.stop_px,
    )

    total_elapsed = time.perf_counter() - overall_start
    total_sent = args.buys + args.sells
    total_succ = res1["success"] + res2["success"]
    total_fail = res1["fail"] + res2["fail"]
    print(
        json.dumps(
            {
                "total_sent": total_sent,
                "total_success": total_succ,
                "total_fail": total_fail,
                "elapsed_sec": round(total_elapsed, 3),
                "overall_rps": (
                    round(total_sent / total_elapsed, 1) if total_elapsed > 0 else 0
                ),
                "phases": [res1, res2],
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
