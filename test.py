import asyncio
import time


async def job(s):
	print(f"0: {s}",flush=True)
	time.sleep(1)
	print(f"1: {s}",flush=True)
	time.sleep(1)
	print(f"2: {s}",flush=True)



async def main():
	await asyncio.gather((job("first"),job("second")))

asyncio.run(main())
