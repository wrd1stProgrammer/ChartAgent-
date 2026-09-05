import pytest
from pydantic import ValidationError

from app.chart_annotations import ChartAnnotation, ChartAnnotationPlan, ImagePoint
from app.errors import AnalysisUnavailableError


def test_annotation_rejects_coordinates_outside_image() -> None:
    with pytest.raises(ValidationError):
        ImagePoint(x=1.2, y=0.3)


def test_annotation_rejects_zero_length_mark() -> None:
    point = ImagePoint(x=0.3, y=0.4)
    with pytest.raises(ValidationError):
        ChartAnnotation(id="a1", kind="line", title="지지 확인", detail="확인 가능한 지지 구간입니다.",
                        outlook="이탈하면 지지 해석을 무효화합니다.", tone="mint", points=[point, point], label_anchor=point)


def test_plan_accepts_unreadable_chart_without_inventing_marks() -> None:
    plan = ChartAnnotationPlan(summary="판독 가능한 가격 차트가 없습니다.", annotations=[])
    assert plan.annotations == []


def test_plan_rejects_duplicate_ids() -> None:
    mark = ChartAnnotation(id="a1", kind="line", title="고점 저항", detail="두 고점이 형성한 저항입니다.",
                           outlook="돌파 확인 전까지 저항이 유지됩니다.", tone="coral", points=[ImagePoint(x=0.2, y=0.3), ImagePoint(x=0.8, y=0.3)],
                           label_anchor=ImagePoint(x=0.5, y=0.15))
    with pytest.raises(ValidationError):
        ChartAnnotationPlan(summary="두 고점의 저항선입니다.", annotations=[mark, mark])


def test_channel_accepts_two_baseline_points_and_opposite_swing() -> None:
    mark = ChartAnnotation(id="a1", kind="channel", title="하락 채널", detail="평행 경계의 반복 접점입니다.",
                           outlook="상단 돌파 시 채널 지속 해석이 약해집니다.", tone="blue", points=[ImagePoint(x=0.2, y=0.3), ImagePoint(x=0.8, y=0.6), ImagePoint(x=0.5, y=0.2)],
                           label_anchor=ImagePoint(x=0.5, y=0.1))
    assert mark.kind == "channel"


def test_channel_rejects_opposite_boundary_outside_image() -> None:
    with pytest.raises(ValidationError):
        ChartAnnotation(id="a1", kind="channel", title="하락 채널", detail="평행 경계의 반복 접점입니다.",
                        outlook="상단 돌파 시 채널 지속 해석이 약해집니다.", tone="blue", points=[ImagePoint(x=0.2, y=0.3), ImagePoint(x=0.8, y=0.9), ImagePoint(x=0.5, y=0.95)],
                        label_anchor=ImagePoint(x=0.5, y=0.1))


def test_report_link_rejects_a_scenario_not_in_the_report() -> None:
    # Given a drawing linked to the third scenario, but a report with only two.
    mark = ChartAnnotation(id="a1", kind="line", title="상승 추세선", detail="높아지는 두 저점이 연결됩니다.",
                           outlook="선을 지키면 반등 유지, 이탈하면 반등 구조가 약해집니다.", scenario_index=2,
                           tone="mint", points=[ImagePoint(x=0.2, y=0.7), ImagePoint(x=0.8, y=0.5)],
                           label_anchor=ImagePoint(x=0.5, y=0.8))
    plan = ChartAnnotationPlan(summary="추세선 유지 여부로 반등 지속을 판단합니다.", annotations=[mark])
    # When the generated link is checked against the actual report, reject it.
    with pytest.raises(AnalysisUnavailableError):
        plan.validate_scenario_links(scenario_count=2)
