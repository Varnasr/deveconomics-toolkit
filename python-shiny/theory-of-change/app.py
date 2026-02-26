"""
Theory of Change Visualizer — Impact Mojo
A Python Shiny application for development sector practitioners to build,
visualize, and export Theories of Change.
"""

import io
import textwrap
from datetime import datetime

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch
import numpy as np
import pandas as pd

from shiny import App, Inputs, Outputs, Session, reactive, render, ui

# ---------------------------------------------------------------------------
# Templates
# ---------------------------------------------------------------------------
TEMPLATES = {
    "Blank": {
        "inputs": "",
        "activities": "",
        "outputs": "",
        "outcomes_short": "",
        "outcomes_medium": "",
        "impact": "",
        "assumptions": "",
    },
    "Education Program": {
        "inputs": "Funding from donors\nTrained teachers\nTextbooks and learning materials\nSchool infrastructure\nGovernment policy support",
        "activities": "Teacher training workshops\nCurriculum development and revision\nSchool construction and rehabilitation\nCommunity engagement campaigns\nMonitoring and evaluation",
        "outputs": "500 teachers trained per year\n20 schools built or renovated\n10,000 textbooks distributed\n50 community meetings held\nRevised curriculum approved",
        "outcomes_short": "Improved teaching quality\nIncreased student enrollment\nHigher attendance rates\nGreater community involvement",
        "outcomes_medium": "Improved test scores (20% increase)\nReduced dropout rates\nIncreased girls' enrollment\nStronger school governance",
        "impact": "Reduced educational inequality\nHigher literacy and numeracy rates\nImproved economic opportunities\nSustainable human capital development",
        "assumptions": "Government maintains education budget\nCommunities are willing to participate\nTeachers remain in post after training\nSecurity situation remains stable\nCurriculum is culturally appropriate",
    },
    "Health Intervention": {
        "inputs": "Community health workers\nVaccines and cold chain equipment\nClinics and mobile health units\nHealth education materials\nPartnership with Ministry of Health",
        "activities": "Vaccination campaigns (EPI)\nHealth education and BCC sessions\nClinic operations and outreach\nTraining of health workers\nSupply chain management",
        "outputs": "50,000 children vaccinated\n200 health education sessions delivered\n10 clinics operational\n300 health workers trained\nMonthly supply deliveries maintained",
        "outcomes_short": "Increased vaccination coverage (>80%)\nImproved health-seeking behavior\nReduced treatment delays\nBetter knowledge of preventive practices",
        "outcomes_medium": "Reduced disease incidence (measles, polio)\nSustained behavior change in hygiene\nStrengthened health system capacity\nReduced malnutrition rates",
        "impact": "Reduced child mortality (under-5)\nImproved life expectancy\nStronger and more resilient health systems\nProgress toward Universal Health Coverage",
        "assumptions": "Vaccines remain effective and available\nCommunity trust in health services\nNo major disease outbreaks overwhelm capacity\nGovernment co-financing continues\nHealth workers are adequately compensated",
    },
    "Livelihoods Program": {
        "inputs": "Microfinance capital\nAgricultural extension officers\nSeeds, tools, and inputs\nMarket access infrastructure\nTraining facilitators",
        "activities": "Vocational skills training\nMicrofinance and savings groups\nAgricultural extension services\nMarket linkage facilitation\nBusiness development support",
        "outputs": "2,000 people trained in vocational skills\n100 savings groups established\n5,000 farmers reached with extension\n10 market linkages created\n500 business plans developed",
        "outcomes_short": "Increased household income (15%)\nDiversified income sources\nImproved agricultural productivity\nGreater financial literacy",
        "outcomes_medium": "Sustainable livelihoods established\nReduced vulnerability to shocks\nWomen's economic empowerment\nLocal market systems strengthened",
        "impact": "Reduced poverty rates\nImproved food security\nGreater economic resilience\nReduced rural-urban migration",
        "assumptions": "Markets remain accessible and functional\nClimate conditions are favorable\nParticipants have baseline literacy\nNo major economic shocks\nGender norms allow women's participation",
    },
    "WASH Program": {
        "inputs": "Water engineers and technicians\nConstruction materials\nHygiene promotion specialists\nCommunity mobilizers\nGovernment WASH policy framework",
        "activities": "Borehole drilling and water point construction\nLatrine construction and sanitation marketing\nHygiene promotion campaigns (CLTS)\nWater committee training\nWater quality testing and monitoring",
        "outputs": "50 boreholes drilled\n1,000 household latrines constructed\n200 hygiene sessions conducted\n50 water committees trained\nMonthly water quality reports produced",
        "outcomes_short": "Increased access to safe water (80%)\nIncreased latrine usage\nImproved handwashing practices\nFunctional water management committees",
        "outcomes_medium": "Reduced waterborne diseases\nOpen defecation-free communities\nSustained hygiene behavior change\nCommunity-managed water systems",
        "impact": "Reduced child morbidity and mortality\nImproved school attendance (especially girls)\nReduced burden on women and girls for water collection\nEnvironmental sustainability",
        "assumptions": "Water table is sufficient for boreholes\nCommunities contribute to maintenance costs\nLocal government supports O&M frameworks\nBehavior change is sustained over time\nSupply chains for spare parts are functional",
    },
}

# ---------------------------------------------------------------------------
# Color schemes
# ---------------------------------------------------------------------------
COLOR_SCHEMES = {
    "Default": {
        "inputs": "#4E79A7",
        "activities": "#F28E2B",
        "outputs": "#E15759",
        "outcomes_short": "#76B7B2",
        "outcomes_medium": "#59A14F",
        "impact": "#EDC948",
        "assumptions": "#B07AA1",
        "text": "#FFFFFF",
        "assumption_text": "#4A4A4A",
        "bg": "#FAFAFA",
        "arrow": "#666666",
    },
    "UNICEF Blue": {
        "inputs": "#1CABE2",
        "activities": "#0058AB",
        "outputs": "#00833D",
        "outcomes_short": "#FFC20E",
        "outcomes_medium": "#F26A21",
        "impact": "#E2231A",
        "assumptions": "#80BD41",
        "text": "#FFFFFF",
        "assumption_text": "#374151",
        "bg": "#F0F8FF",
        "arrow": "#1CABE2",
    },
    "World Bank": {
        "inputs": "#002244",
        "activities": "#004C8C",
        "outputs": "#0072BC",
        "outcomes_short": "#009FDA",
        "outcomes_medium": "#58B5E1",
        "impact": "#002244",
        "assumptions": "#7F8C8D",
        "text": "#FFFFFF",
        "assumption_text": "#2C3E50",
        "bg": "#F5F5F0",
        "arrow": "#002244",
    },
    "Custom (Earth Tones)": {
        "inputs": "#8B4513",
        "activities": "#CD853F",
        "outputs": "#D2691E",
        "outcomes_short": "#6B8E23",
        "outcomes_medium": "#556B2F",
        "impact": "#2E4A1E",
        "assumptions": "#A0522D",
        "text": "#FFFFFF",
        "assumption_text": "#3E2723",
        "bg": "#FFF8F0",
        "arrow": "#5D4037",
    },
}

LEVEL_KEYS = [
    "inputs",
    "activities",
    "outputs",
    "outcomes_short",
    "outcomes_medium",
    "impact",
]
LEVEL_LABELS = {
    "inputs": "Inputs / Resources",
    "activities": "Activities",
    "outputs": "Outputs",
    "outcomes_short": "Outcomes (Short-term)",
    "outcomes_medium": "Outcomes (Medium-term)",
    "impact": "Impact (Long-term)",
}

# ---------------------------------------------------------------------------
# Helper utilities
# ---------------------------------------------------------------------------

def parse_lines(text: str) -> list[str]:
    """Split text on newlines, strip whitespace, and remove blanks."""
    if not text:
        return []
    return [line.strip() for line in text.strip().split("\n") if line.strip()]


def wrap_text(text: str, width: int = 22) -> str:
    """Wrap text for display inside boxes."""
    return "\n".join(textwrap.wrap(text, width=width))


# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------

app_ui = ui.page_sidebar(
    ui.sidebar(
        ui.h4("Configuration"),
        ui.input_select(
            "template",
            "Load Template",
            choices=list(TEMPLATES.keys()),
            selected="Blank",
        ),
        ui.hr(),
        ui.h5("Theory of Change Elements"),
        ui.p("Enter one item per line for each level.", style="font-size:0.85em; color:#666;"),
        ui.input_text_area(
            "inputs",
            "Inputs / Resources",
            value="",
            rows=3,
            placeholder="e.g., Funding from donors\nTrained staff\nEquipment",
        ),
        ui.input_text_area(
            "activities",
            "Activities",
            value="",
            rows=3,
            placeholder="e.g., Training workshops\nCommunity outreach",
        ),
        ui.input_text_area(
            "outputs",
            "Outputs",
            value="",
            rows=3,
            placeholder="e.g., 500 people trained\n10 facilities built",
        ),
        ui.input_text_area(
            "outcomes_short",
            "Outcomes (Short-term)",
            value="",
            rows=3,
            placeholder="e.g., Improved knowledge\nBehavior change",
        ),
        ui.input_text_area(
            "outcomes_medium",
            "Outcomes (Medium-term)",
            value="",
            rows=3,
            placeholder="e.g., Reduced incidence\nSustained change",
        ),
        ui.input_text_area(
            "impact",
            "Impact (Long-term)",
            value="",
            rows=3,
            placeholder="e.g., Reduced poverty\nImproved well-being",
        ),
        ui.hr(),
        ui.input_text_area(
            "assumptions",
            "Assumptions",
            value="",
            rows=3,
            placeholder="e.g., Political stability\nCommunity buy-in",
        ),
        ui.hr(),
        ui.h5("Display Options"),
        ui.input_select(
            "color_scheme",
            "Color Scheme",
            choices=list(COLOR_SCHEMES.keys()),
            selected="Default",
        ),
        ui.input_switch("show_assumptions", "Show assumptions on diagram", value=True),
        ui.hr(),
        ui.download_button("export_txt", "Export as Text Summary", class_="btn btn-outline-primary w-100"),
        width=380,
    ),
    ui.navset_tab(
        ui.nav_panel(
            "Diagram",
            ui.output_plot("toc_diagram", height="750px", width="100%"),
        ),
        ui.nav_panel(
            "Summary Table",
            ui.output_table("summary_table"),
        ),
        ui.nav_panel(
            "Narrative",
            ui.output_ui("narrative"),
        ),
        ui.nav_panel(
            "About",
            ui.output_ui("about_page"),
        ),
    ),
    title="Theory of Change Visualizer \u2014 Impact Mojo",
    fillable=True,
)


# ---------------------------------------------------------------------------
# Server
# ---------------------------------------------------------------------------

def server(input: Inputs, output: Outputs, session: Session):

    # -- Template population ------------------------------------------------

    @reactive.effect
    @reactive.event(input.template)
    def _update_template():
        t = TEMPLATES.get(input.template(), TEMPLATES["Blank"])
        for key in LEVEL_KEYS:
            ui.update_text_area(key, value=t[key])
        ui.update_text_area("assumptions", value=t["assumptions"])

    # -- Reactive data helpers ---------------------------------------------

    @reactive.calc
    def toc_data() -> dict[str, list[str]]:
        data: dict[str, list[str]] = {}
        for key in LEVEL_KEYS:
            data[key] = parse_lines(getattr(input, key)())
        data["assumptions"] = parse_lines(input.assumptions())
        return data

    # -- Diagram tab -------------------------------------------------------

    @render.plot
    def toc_diagram():
        data = toc_data()
        scheme_name = input.color_scheme()
        colors = COLOR_SCHEMES.get(scheme_name, COLOR_SCHEMES["Default"])
        show_assumptions = input.show_assumptions()

        # Determine which levels have content
        active_levels = [k for k in LEVEL_KEYS if data[k]]
        if not active_levels:
            fig, ax = plt.subplots(figsize=(12, 6))
            ax.text(
                0.5, 0.5,
                "Enter items in the sidebar to build your\nTheory of Change diagram.",
                ha="center", va="center", fontsize=16, color="#999999",
                transform=ax.transAxes,
            )
            ax.set_xlim(0, 1)
            ax.set_ylim(0, 1)
            ax.axis("off")
            fig.patch.set_facecolor(colors["bg"])
            return fig

        n_levels = len(active_levels)
        max_items = max(len(data[k]) for k in active_levels) if active_levels else 1

        # Layout parameters
        box_w = 1.0
        box_h_base = 0.55
        col_spacing = 1.65
        row_spacing = 0.85

        fig_w = n_levels * col_spacing + 2.0
        fig_h = max(max_items * row_spacing + 3.0, 6.0)

        fig, ax = plt.subplots(figsize=(fig_w, fig_h))
        fig.patch.set_facecolor(colors["bg"])
        ax.set_facecolor(colors["bg"])

        # Compute positions (left-to-right flow)
        level_positions: dict[str, list[tuple[float, float]]] = {}
        level_centers: dict[str, tuple[float, float]] = {}

        for col_idx, level_key in enumerate(active_levels):
            items = data[level_key]
            n_items = len(items)
            x_center = 1.0 + col_idx * col_spacing
            total_height = (n_items - 1) * row_spacing
            y_start = (fig_h / 2.0) + total_height / 2.0

            positions = []
            for row_idx in range(n_items):
                y = y_start - row_idx * row_spacing
                positions.append((x_center, y))
            level_positions[level_key] = positions

            # Center of level column (for arrows between levels)
            y_mean = np.mean([p[1] for p in positions]) if positions else fig_h / 2.0
            level_centers[level_key] = (x_center, y_mean)

        # Draw boxes
        for level_key in active_levels:
            items = data[level_key]
            color = colors[level_key]
            for idx, (x, y) in enumerate(level_positions[level_key]):
                label = wrap_text(items[idx], width=18)
                # Compute box height based on text lines
                n_lines = label.count("\n") + 1
                bh = max(box_h_base, 0.22 * n_lines + 0.18)
                rect = FancyBboxPatch(
                    (x - box_w / 2, y - bh / 2),
                    box_w, bh,
                    boxstyle="round,pad=0.06",
                    facecolor=color,
                    edgecolor="white",
                    linewidth=1.5,
                    zorder=3,
                )
                ax.add_patch(rect)
                # Choose text color: for light backgrounds use dark text
                txt_color = colors["text"]
                if level_key == "impact" and scheme_name == "Default":
                    txt_color = "#333333"
                ax.text(
                    x, y, label,
                    ha="center", va="center",
                    fontsize=7.5, fontweight="bold",
                    color=txt_color,
                    zorder=4,
                    linespacing=1.2,
                )

        # Draw level headers
        for level_key in active_levels:
            x_c, _ = level_centers[level_key]
            header_y = fig_h - 0.6
            ax.text(
                x_c, header_y,
                LEVEL_LABELS[level_key],
                ha="center", va="center",
                fontsize=9, fontweight="bold",
                color="#333333",
                zorder=5,
                bbox=dict(
                    boxstyle="round,pad=0.3",
                    facecolor="white",
                    edgecolor=colors[level_key],
                    linewidth=2,
                    alpha=0.95,
                ),
            )

        # Draw arrows between adjacent levels
        for i in range(len(active_levels) - 1):
            left_key = active_levels[i]
            right_key = active_levels[i + 1]

            left_items = level_positions[left_key]
            right_items = level_positions[right_key]

            # Draw one arrow from each left item center-right to each right item center-left
            # For readability, connect center-of-level to center-of-level with a thick arrow
            lx = left_items[0][0] + box_w / 2 + 0.05
            rx = right_items[0][0] - box_w / 2 - 0.05
            ly = np.mean([p[1] for p in left_items])
            ry = np.mean([p[1] for p in right_items])

            arrow = FancyArrowPatch(
                (lx, ly), (rx, ry),
                arrowstyle="-|>",
                mutation_scale=18,
                linewidth=2.5,
                color=colors["arrow"],
                alpha=0.6,
                connectionstyle="arc3,rad=0.0",
                zorder=2,
            )
            ax.add_patch(arrow)

        # Draw assumptions
        if show_assumptions and data["assumptions"]:
            assumption_text = "ASSUMPTIONS:\n" + "\n".join(
                f"  \u2022 {a}" for a in data["assumptions"]
            )
            wrapped = "\n".join(
                textwrap.fill(line, width=55) for line in assumption_text.split("\n")
            )
            ax.text(
                fig_w / 2.0, 0.35,
                wrapped,
                ha="center", va="bottom",
                fontsize=7, fontstyle="italic",
                color=colors["assumption_text"],
                zorder=5,
                bbox=dict(
                    boxstyle="round,pad=0.4",
                    facecolor="white",
                    edgecolor=colors["assumptions"],
                    linewidth=1.5,
                    linestyle="dashed",
                    alpha=0.92,
                ),
            )

        # Final axis setup
        ax.set_xlim(-0.2, fig_w + 0.2)
        ax.set_ylim(-0.2, fig_h + 0.2)
        ax.axis("off")
        fig.tight_layout(pad=0.5)
        return fig

    # -- Summary Table tab -------------------------------------------------

    @render.table
    def summary_table():
        data = toc_data()
        rows = []
        for key in LEVEL_KEYS:
            items = data[key]
            label = LEVEL_LABELS[key]
            if items:
                for i, item in enumerate(items, start=1):
                    rows.append({
                        "Level": label,
                        "#": i,
                        "Description": item,
                    })
            else:
                rows.append({
                    "Level": label,
                    "#": "",
                    "Description": "(none entered)",
                })
        if data["assumptions"]:
            for i, a in enumerate(data["assumptions"], start=1):
                rows.append({
                    "Level": "Assumptions",
                    "#": i,
                    "Description": a,
                })
        df = pd.DataFrame(rows)
        return df

    # -- Narrative tab -----------------------------------------------------

    @render.ui
    def narrative():
        data = toc_data()
        has_content = any(data[k] for k in LEVEL_KEYS)

        if not has_content:
            return ui.div(
                ui.p(
                    "Enter items in the sidebar to generate a narrative description of your Theory of Change.",
                    style="color:#999; font-style:italic; padding:2em;",
                ),
            )

        # Build narrative parts
        parts = []
        parts.append(
            ui.h4("Theory of Change Narrative", style="margin-bottom:1em;")
        )
        parts.append(ui.hr())

        # Opening paragraph
        opening = "This Theory of Change describes the causal pathway through which the program intends to achieve its intended long-term impact."
        parts.append(ui.p(opening, style="font-size:1.05em; line-height:1.7;"))

        # Inputs
        if data["inputs"]:
            items_str = _join_list(data["inputs"])
            para = f"By mobilizing key inputs and resources \u2014 including {items_str} \u2014 the program establishes the foundation necessary for implementation."
            parts.append(ui.p(ui.strong("Inputs & Resources: "), para, style="line-height:1.7;"))

        # Activities
        if data["activities"]:
            items_str = _join_list(data["activities"])
            para = f"With these resources in place, the program will undertake the following core activities: {items_str}."
            parts.append(ui.p(ui.strong("Activities: "), para, style="line-height:1.7;"))

        # Outputs
        if data["outputs"]:
            items_str = _join_list(data["outputs"])
            para = f"These activities are expected to produce measurable outputs, specifically: {items_str}."
            parts.append(ui.p(ui.strong("Outputs: "), para, style="line-height:1.7;"))

        # Short-term outcomes
        if data["outcomes_short"]:
            items_str = _join_list(data["outcomes_short"])
            para = f"In the short term, the program expects to see changes such as {items_str}."
            parts.append(ui.p(ui.strong("Short-term Outcomes: "), para, style="line-height:1.7;"))

        # Medium-term outcomes
        if data["outcomes_medium"]:
            items_str = _join_list(data["outcomes_medium"])
            para = f"Over the medium term, these early changes are expected to contribute to {items_str}."
            parts.append(ui.p(ui.strong("Medium-term Outcomes: "), para, style="line-height:1.7;"))

        # Impact
        if data["impact"]:
            items_str = _join_list(data["impact"])
            para = f"Ultimately, the program aims to contribute to the following long-term impacts: {items_str}."
            parts.append(ui.p(ui.strong("Long-term Impact: "), para, style="line-height:1.7;"))

        # Assumptions
        if data["assumptions"]:
            parts.append(ui.hr())
            parts.append(ui.h5("Key Assumptions"))
            para = "This Theory of Change rests on several critical assumptions. If these do not hold, the causal pathway may be disrupted:"
            parts.append(ui.p(para, style="line-height:1.7;"))
            assumption_items = [ui.tags.li(a) for a in data["assumptions"]]
            parts.append(ui.tags.ul(*assumption_items, style="line-height:1.8;"))

        # Closing
        parts.append(ui.hr())
        parts.append(
            ui.p(
                "This narrative was auto-generated based on the elements entered. "
                "It should be reviewed and refined collaboratively with stakeholders "
                "to ensure it accurately reflects the program's logic and context.",
                style="font-size:0.9em; color:#777; font-style:italic;",
            )
        )

        return ui.div(
            *parts,
            style="max-width:800px; padding:1.5em 2em; background:white; border-radius:8px; box-shadow: 0 1px 4px rgba(0,0,0,0.08);",
        )

    # -- About tab ---------------------------------------------------------

    @render.ui
    def about_page():
        return ui.div(
            ui.h3("About the Theory of Change Methodology"),
            ui.hr(),
            ui.h4("What is a Theory of Change?"),
            ui.p(
                "A Theory of Change (ToC) is a comprehensive description and illustration of how and why "
                "a desired change is expected to happen in a particular context. It maps out the causal "
                "pathway from inputs and activities through to long-term impact, making explicit the "
                "assumptions underlying each step.",
                style="line-height:1.7;",
            ),
            ui.p(
                "Originally developed in the field of program evaluation in the 1990s \u2014 notably through "
                "the work of Carol Weiss at Harvard and the Aspen Institute's Roundtable on Community "
                "Change \u2014 the Theory of Change approach has become a cornerstone of program design, "
                "monitoring, and evaluation across the international development sector.",
                style="line-height:1.7;",
            ),
            ui.hr(),
            ui.h4("Key Components"),
            ui.tags.table(
                ui.tags.thead(
                    ui.tags.tr(
                        ui.tags.th("Component", style="padding:8px 16px; background:#f0f0f0;"),
                        ui.tags.th("Description", style="padding:8px 16px; background:#f0f0f0;"),
                    ),
                ),
                ui.tags.tbody(
                    ui.tags.tr(
                        ui.tags.td(ui.strong("Inputs / Resources"), style="padding:8px 16px;"),
                        ui.tags.td("The financial, human, and material resources invested in the program.", style="padding:8px 16px;"),
                    ),
                    ui.tags.tr(
                        ui.tags.td(ui.strong("Activities"), style="padding:8px 16px;"),
                        ui.tags.td("The actions taken or work performed using the inputs.", style="padding:8px 16px;"),
                    ),
                    ui.tags.tr(
                        ui.tags.td(ui.strong("Outputs"), style="padding:8px 16px;"),
                        ui.tags.td("The direct, tangible products of activities (e.g., number of people trained).", style="padding:8px 16px;"),
                    ),
                    ui.tags.tr(
                        ui.tags.td(ui.strong("Outcomes"), style="padding:8px 16px;"),
                        ui.tags.td("Changes in behavior, knowledge, skills, status, or functioning that result from outputs. Often divided into short-term and medium-term.", style="padding:8px 16px;"),
                    ),
                    ui.tags.tr(
                        ui.tags.td(ui.strong("Impact"), style="padding:8px 16px;"),
                        ui.tags.td("The long-term, sustainable change at population or systems level.", style="padding:8px 16px;"),
                    ),
                    ui.tags.tr(
                        ui.tags.td(ui.strong("Assumptions"), style="padding:8px 16px;"),
                        ui.tags.td("The conditions necessary for the causal links to hold. These represent risks if they prove false.", style="padding:8px 16px;"),
                    ),
                ),
                style="border-collapse:collapse; width:100%; margin:1em 0;",
            ),
            ui.hr(),
            ui.h4("Theory of Change in Development Practice"),
            ui.p(
                "The ToC approach is now required or recommended by many of the world's leading "
                "development organizations:",
                style="line-height:1.7;",
            ),
            ui.tags.ul(
                ui.tags.li(
                    ui.strong("DFID / FCDO (UK): "),
                    "The Department for International Development (now FCDO) was one of the earliest "
                    "adopters, requiring Theories of Change for all major programs. Their guidance "
                    "emphasizes ToC as a living document that evolves with the program.",
                ),
                ui.tags.li(
                    ui.strong("USAID: "),
                    "The US Agency for International Development integrates ToC into its Program "
                    "Cycle guidance (ADS 201). ToC is a core element of project design documents "
                    "and Collaboration, Learning, and Adapting (CLA) frameworks.",
                ),
                ui.tags.li(
                    ui.strong("World Bank: "),
                    "The World Bank uses ToC in its results frameworks and Independent Evaluation "
                    "Group (IEG) assessments. It is central to the Bank's emphasis on results-based "
                    "management.",
                ),
                ui.tags.li(
                    ui.strong("UNDP, UNICEF, and UN Agencies: "),
                    "UN agencies increasingly use ToC in country programme documents and as part "
                    "of the UN Sustainable Development Cooperation Framework (UNSDCF).",
                ),
                ui.tags.li(
                    ui.strong("Major Foundations: "),
                    "The Bill & Melinda Gates Foundation, Ford Foundation, and others require or "
                    "encourage ToC as part of grant proposals.",
                ),
                style="line-height:1.8;",
            ),
            ui.hr(),
            ui.h4("Theory of Change vs. Logical Framework (LogFrame)"),
            ui.p(
                "While both are results-based planning tools, they differ in important ways:",
                style="line-height:1.7;",
            ),
            ui.tags.table(
                ui.tags.thead(
                    ui.tags.tr(
                        ui.tags.th("Aspect", style="padding:8px 16px; background:#f0f0f0;"),
                        ui.tags.th("Theory of Change", style="padding:8px 16px; background:#f0f0f0;"),
                        ui.tags.th("Logical Framework", style="padding:8px 16px; background:#f0f0f0;"),
                    ),
                ),
                ui.tags.tbody(
                    ui.tags.tr(
                        ui.tags.td("Focus", style="padding:8px 16px;"),
                        ui.tags.td("Why and how change happens", style="padding:8px 16px;"),
                        ui.tags.td("What will be delivered and measured", style="padding:8px 16px;"),
                    ),
                    ui.tags.tr(
                        ui.tags.td("Structure", style="padding:8px 16px;"),
                        ui.tags.td("Flexible, visual, often non-linear", style="padding:8px 16px;"),
                        ui.tags.td("Rigid 4x4 matrix (Goal, Purpose, Outputs, Activities)", style="padding:8px 16px;"),
                    ),
                    ui.tags.tr(
                        ui.tags.td("Assumptions", style="padding:8px 16px;"),
                        ui.tags.td("Central to the analysis; explicitly mapped to each link", style="padding:8px 16px;"),
                        ui.tags.td("Listed but often not deeply analyzed", style="padding:8px 16px;"),
                    ),
                    ui.tags.tr(
                        ui.tags.td("Complexity", style="padding:8px 16px;"),
                        ui.tags.td("Can handle complex, multi-pathway change", style="padding:8px 16px;"),
                        ui.tags.td("Best for simple linear logic", style="padding:8px 16px;"),
                    ),
                    ui.tags.tr(
                        ui.tags.td("Usage", style="padding:8px 16px;"),
                        ui.tags.td("Strategic planning, evaluation, learning", style="padding:8px 16px;"),
                        ui.tags.td("Project management, reporting, accountability", style="padding:8px 16px;"),
                    ),
                    ui.tags.tr(
                        ui.tags.td("Adaptability", style="padding:8px 16px;"),
                        ui.tags.td("Designed to evolve; encourages iteration", style="padding:8px 16px;"),
                        ui.tags.td("Often static once approved", style="padding:8px 16px;"),
                    ),
                ),
                style="border-collapse:collapse; width:100%; margin:1em 0;",
            ),
            ui.p(
                "In practice, many organizations use both: a ToC for strategic thinking and stakeholder "
                "dialogue, and a LogFrame (derived from the ToC) for operational management and donor "
                "reporting. The ToC provides the 'why' and the LogFrame provides the 'what'.",
                style="line-height:1.7; font-style:italic; color:#555;",
            ),
            ui.hr(),
            ui.h4("Tips for Designing a Good Theory of Change"),
            ui.tags.ol(
                ui.tags.li(
                    ui.strong("Start from the impact and work backwards. "),
                    "Define the long-term change you want to see, then trace back the "
                    "necessary preconditions. This 'backwards mapping' approach helps ensure "
                    "your logic is driven by the goal, not just by available activities.",
                ),
                ui.tags.li(
                    ui.strong("Be explicit about assumptions. "),
                    "Every causal link rests on assumptions. Making them explicit allows you "
                    "to test them, monitor them, and adapt when they prove wrong.",
                ),
                ui.tags.li(
                    ui.strong("Engage stakeholders. "),
                    "A ToC should not be developed in isolation. Involve beneficiaries, "
                    "partners, government counterparts, and frontline staff. Their perspectives "
                    "strengthen the logic and build ownership.",
                ),
                ui.tags.li(
                    ui.strong("Use evidence. "),
                    "Ground your causal links in evidence from research, evaluations, and "
                    "local knowledge. Where evidence is weak, acknowledge it and plan to "
                    "generate evidence through your M&E system.",
                ),
                ui.tags.li(
                    ui.strong("Keep it clear and concise. "),
                    "A ToC should be understandable at a glance. If your diagram requires "
                    "extensive explanation, simplify it. Use clear language, not jargon.",
                ),
                ui.tags.li(
                    ui.strong("Treat it as a living document. "),
                    "Revisit and revise your ToC regularly as you learn from implementation. "
                    "A ToC that never changes is probably not being used.",
                ),
                ui.tags.li(
                    ui.strong("Distinguish between contribution and attribution. "),
                    "Your program likely contributes to impact alongside other factors. "
                    "Be honest about what you can claim.",
                ),
                ui.tags.li(
                    ui.strong("Consider unintended consequences. "),
                    "Think about potential negative effects and include them in your analysis. "
                    "This demonstrates rigor and helps mitigate risks.",
                ),
                style="line-height:1.8;",
            ),
            ui.hr(),
            ui.h4("References"),
            ui.tags.ul(
                ui.tags.li(
                    "Weiss, C. H. (1995). 'Nothing as Practical as Good Theory: Exploring Theory-Based "
                    "Evaluation for Comprehensive Community Initiatives for Children and Families.' "
                    "In J. Connell et al. (Eds.), ",
                    ui.tags.em("New Approaches to Evaluating Community Initiatives"),
                    ". Washington, DC: Aspen Institute.",
                ),
                ui.tags.li(
                    "Vogel, I. (2012). ",
                    ui.tags.em("Review of the Use of 'Theory of Change' in International Development"),
                    ". London: DFID.",
                ),
                ui.tags.li(
                    "Mayne, J. (2015). 'Useful Theory of Change Models.' ",
                    ui.tags.em("Canadian Journal of Program Evaluation"),
                    ", 30(2), 119\u2013142.",
                ),
                ui.tags.li(
                    "USAID (2016). ",
                    ui.tags.em("ADS Chapter 201: Program Cycle Operational Policy"),
                    ". Washington, DC: USAID.",
                ),
                ui.tags.li(
                    "Taplin, D. H., & Clark, H. (2012). ",
                    ui.tags.em("Theory of Change Basics: A Primer on Theory of Change"),
                    ". New York: ActKnowledge.",
                ),
                ui.tags.li(
                    "Funnell, S. C., & Rogers, P. J. (2011). ",
                    ui.tags.em("Purposeful Program Theory: Effective Use of Theories of Change and Logic Models"),
                    ". San Francisco: Jossey-Bass.",
                ),
                ui.tags.li(
                    "World Bank Independent Evaluation Group (2012). ",
                    ui.tags.em("Designing a Results Framework for Achieving Results: A How-To Guide"),
                    ". Washington, DC: World Bank.",
                ),
                style="line-height:2.0;",
            ),
            ui.hr(),
            ui.p(
                "Impact Mojo \u2014 Tools for Development Practitioners. "
                "This application is provided as-is for educational and professional use.",
                style="font-size:0.85em; color:#999; text-align:center; padding-top:0.5em;",
            ),
            style="max-width:900px; padding:1.5em 2em; background:white; border-radius:8px; "
                   "box-shadow: 0 1px 4px rgba(0,0,0,0.08); line-height:1.6;",
        )

    # -- Export ------------------------------------------------------------

    @render.download(filename=lambda: f"theory_of_change_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt")
    def export_txt():
        data = toc_data()
        lines = []
        lines.append("=" * 70)
        lines.append("THEORY OF CHANGE SUMMARY")
        lines.append(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        lines.append("Tool: Theory of Change Visualizer \u2014 Impact Mojo")
        lines.append("=" * 70)
        lines.append("")

        for key in LEVEL_KEYS:
            label = LEVEL_LABELS[key]
            items = data[key]
            lines.append(f"--- {label.upper()} ---")
            if items:
                for i, item in enumerate(items, start=1):
                    lines.append(f"  {i}. {item}")
            else:
                lines.append("  (none)")
            lines.append("")

        lines.append("--- ASSUMPTIONS ---")
        if data["assumptions"]:
            for i, a in enumerate(data["assumptions"], start=1):
                lines.append(f"  {i}. {a}")
        else:
            lines.append("  (none)")
        lines.append("")

        # Auto-narrative
        lines.append("=" * 70)
        lines.append("NARRATIVE SUMMARY")
        lines.append("=" * 70)
        lines.append("")
        lines.append(
            "This Theory of Change describes the causal pathway through which the "
            "program intends to achieve its intended long-term impact."
        )
        lines.append("")

        if data["inputs"]:
            lines.append(
                f"By mobilizing key inputs and resources -- including "
                f"{_join_list(data['inputs'])} -- the program establishes the "
                f"foundation necessary for implementation."
            )
            lines.append("")
        if data["activities"]:
            lines.append(
                f"With these resources in place, the program will undertake the "
                f"following core activities: {_join_list(data['activities'])}."
            )
            lines.append("")
        if data["outputs"]:
            lines.append(
                f"These activities are expected to produce measurable outputs, "
                f"specifically: {_join_list(data['outputs'])}."
            )
            lines.append("")
        if data["outcomes_short"]:
            lines.append(
                f"In the short term, the program expects to see changes such as "
                f"{_join_list(data['outcomes_short'])}."
            )
            lines.append("")
        if data["outcomes_medium"]:
            lines.append(
                f"Over the medium term, these early changes are expected to contribute "
                f"to {_join_list(data['outcomes_medium'])}."
            )
            lines.append("")
        if data["impact"]:
            lines.append(
                f"Ultimately, the program aims to contribute to the following "
                f"long-term impacts: {_join_list(data['impact'])}."
            )
            lines.append("")
        if data["assumptions"]:
            lines.append(
                "Key assumptions underpinning this theory include: "
                f"{_join_list(data['assumptions'])}."
            )
            lines.append("")

        lines.append("=" * 70)
        lines.append("END OF SUMMARY")
        lines.append("=" * 70)

        yield "\n".join(lines)


def _join_list(items: list[str]) -> str:
    """Join a list of strings with commas and 'and'."""
    if not items:
        return ""
    if len(items) == 1:
        return items[0].lower()
    return ", ".join(item.lower() for item in items[:-1]) + ", and " + items[-1].lower()


# ---------------------------------------------------------------------------
# App object
# ---------------------------------------------------------------------------

app = App(app_ui, server)
