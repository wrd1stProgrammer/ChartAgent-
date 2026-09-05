"""Generate real local model reports and annotation responses for iOS result QA."""
from __future__ import annotations

import argparse
from datetime import UTC, datetime
import json
from pathlib import Path
from uuid import uuid4

import anyio
import httpx

from app.config import get_settings
from app.chart_annotations import AnnotationReportContext
from app.prompts import build_analysis_prompt
from app.providers.codex_cli import CodexCLIProvider
from app.schemas import AnalysisPayload, AnalysisRequestContext, SymbolInfo


async def main(manifest_path: Path, api_url: str, selected_cases: list[str], selected_locales: list[str]) -> None:
    cases = json.loads(manifest_path.read_text())
    settings = get_settings()
    provider = CodexCLIProvider(settings)
    limiter = anyio.Semaphore(2)
    output = manifest_path.parent

    async def run(case: dict[str, str], locale: str) -> None:
        async with limiter:
            name = f"{case['name']}-{locale}"
            record_path = output / f"{name}-record.json"
            annotations_path = output / f"{name}-annotations.json"
            image_path = Path(case['image'])
            symbol = SymbolInfo(code=case['symbol_code'], name=case['symbol_name'], instrument_type=case['instrument_type'])
            context = AnalysisRequestContext(symbol_code=symbol.code, timeframe=case['timeframe'], include_news=False,
                                             active_agent_ids=['trend', 'pattern', 'momentum', 'risk', 'devil'])
            if not record_path.exists():
                prompt = build_analysis_prompt(context, symbol, [])
                prompt = prompt.replace('for a Korean mobile app', 'for a multilingual mobile app')
                prompt = prompt.replace('Write concise natural Korean.', f'Write all user-facing text in locale {locale}.')
                prompt = prompt.replace('complete natural Korean spoken sentence', f'complete natural spoken sentence in locale {locale}')
                payload = await provider.complete(prompt=prompt, image_path=image_path, response_model=AnalysisPayload)
                record = dict(id=str(uuid4()), created_at=datetime.now(UTC).strftime('%Y-%m-%dT%H:%M:%SZ'), provider='codex_cli',
                              symbol=symbol.model_dump(), timeframe=case['timeframe'], included_news=False,
                              result=payload.model_dump(), news=[])
                record_path.write_text(json.dumps(record, ensure_ascii=False, indent=2)+'\n')
                print(f'{name}: real analysis saved', flush=True)
            else:
                record = json.loads(record_path.read_text())
            if not annotations_path.exists():
                result = record['result']
                trend = next((opinion for opinion in result['agent_opinions'] if opinion['agent_id'] == 'trend'), None)
                plan = result.get('trade_plan') or {}
                report_context = AnnotationReportContext(
                    consensus=result['consensus'], scenarios=result['scenarios'], structure=result['structure'],
                    trend_evidence=([trend['thesis']] + trend['evidence'])[:6] if trend else [],
                    trigger=plan.get('trigger'), invalidation=plan.get('stop'), target=plan.get('target'),
                )
                async with httpx.AsyncClient(timeout=150) as client:
                    response = await client.post(api_url + '/chart-annotations',
                        files={'image': (image_path.name, image_path.read_bytes(), 'image/png')},
                        data={'locale': locale, 'report_context': report_context.model_dump_json()})
                    response.raise_for_status()
                    annotations_path.write_text(json.dumps(response.json(), ensure_ascii=False, indent=2)+'\n')
                print(f'{name}: live annotation API result saved', flush=True)

    async with anyio.create_task_group() as group:
        for case in cases:
            if selected_cases and case['name'] not in selected_cases:
                continue
            if not selected_locales or 'ko' in selected_locales:
                group.start_soon(run, case, 'ko')
            if case['name'] == 'eth' and (not selected_locales or 'en-US' in selected_locales):
                group.start_soon(run, case, 'en-US')
            if case['name'] == 'spcx' and (not selected_locales or 'ja' in selected_locales):
                group.start_soon(run, case, 'ja')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('manifest', type=Path)
    parser.add_argument('--api-url', default='http://127.0.0.1:8017/v2')
    parser.add_argument('--case', action='append', default=[])
    parser.add_argument('--locale', action='append', choices=['ko', 'en-US', 'ja'], default=[])
    args = parser.parse_args()
    anyio.run(main, args.manifest, args.api_url, args.case, args.locale)
