###############################################################################
# LogFrame Builder — Impact Mojo
# A Logical Framework (LogFrame) Builder for development sector practitioners
# Self-contained Shiny application
###############################################################################

library(shiny)
library(dplyr)

# =============================================================================
# TEMPLATES
# =============================================================================

get_template <- function(template_name) {
  templates <- list(
    "Blank" = list(
      goal_narrative = "",
      goal_ovi = "",
      goal_mov = "",
      goal_assumptions = "",
      purpose_narrative = "",
      purpose_ovi = "",
      purpose_mov = "",
      purpose_assumptions = "",
      outputs = list(
        list(
          narrative = "", ovi = "", mov = "", assumptions = "",
          activities = list(
            list(narrative = "", ovi = "", mov = "", assumptions = "")
          )
        )
      )
    ),
    "Education" = list(
      goal_narrative = "Improved human capital development and socioeconomic outcomes in target communities",
      goal_ovi = "Human Development Index score in target districts increases by 10% over baseline by 2030",
      goal_mov = "National HDI reports; UNESCO education statistics; National census data",
      goal_assumptions = "Political stability maintained; Government continues to prioritize education sector funding",
      purpose_narrative = "Increased primary school completion rates among children aged 6-14 in target districts",
      purpose_ovi = "Primary completion rate increases from 62% to 85% in target districts within 5 years; Gender parity index reaches 0.95",
      purpose_mov = "Annual school census data; EMIS records; Independent evaluation reports; Household surveys",
      purpose_assumptions = "Families willing to send children to school; No major disease outbreaks disrupting attendance; Economic conditions do not force increased child labor",
      outputs = list(
        list(
          narrative = "Output 1: Primary school teachers trained in learner-centered pedagogy and subject content",
          ovi = "500 teachers complete certified training program (min 80% pass rate); 80% of trained teachers demonstrate improved classroom practices at 6-month follow-up",
          mov = "Training attendance registers and certificates; Classroom observation reports; Pre/post competency test scores",
          assumptions = "Trained teachers remain in their posts; School management supports implementation of new methods",
          activities = list(
            list(
              narrative = "Activity 1.1: Conduct 10-day intensive teacher training workshops in each target district",
              ovi = "20 workshops conducted across 5 districts; 500 teachers enrolled and 475 complete full program",
              mov = "Workshop reports; Attendance sheets; Training evaluation forms; Facilitator reports",
              assumptions = "Qualified facilitators available; Teachers released from duties to attend; Venues available"
            ),
            list(
              narrative = "Activity 1.2: Establish school-based teacher learning circles for peer mentoring",
              ovi = "50 learning circles established; Monthly meetings held with 80% average attendance",
              mov = "Learning circle meeting minutes; Attendance records; Quarterly progress reports",
              assumptions = "Teachers motivated to participate voluntarily; Head teachers provide time during school hours"
            )
          )
        ),
        list(
          narrative = "Output 2: School infrastructure rehabilitated and learning environments improved",
          ovi = "30 schools rehabilitated to meet minimum infrastructure standards; All rehabilitated schools have functional WASH facilities",
          mov = "Construction completion certificates; School inspection reports; Photo documentation; Engineer assessment reports",
          assumptions = "Construction materials available locally; Community provides agreed labor contribution; Weather conditions allow construction during planned period",
          activities = list(
            list(
              narrative = "Activity 2.1: Procure construction materials and engage contractors for school rehabilitation",
              ovi = "30 contractor agreements signed; Materials procured within budget for all target schools",
              mov = "Procurement records; Contractor agreements; Delivery receipts; Financial records",
              assumptions = "Competitive bids received; Supply chains not disrupted; Costs remain within budget estimates"
            ),
            list(
              narrative = "Activity 2.2: Distribute textbooks and learning materials to target schools",
              ovi = "45,000 textbooks distributed achieving 1:1 student-textbook ratio in core subjects",
              mov = "Distribution records; School inventory logs; Student-textbook ratio surveys",
              assumptions = "Textbooks printed on time; Distribution logistics manageable; Schools have secure storage"
            )
          )
        )
      )
    ),
    "Health" = list(
      goal_narrative = "Reduced under-5 mortality rate in target regions contributing to national health targets",
      goal_ovi = "Under-5 mortality rate reduced from 78 to 50 per 1,000 live births in target regions by 2030",
      goal_mov = "National DHS surveys; HMIS data; WHO/UNICEF mortality estimates; Vital registration records",
      goal_assumptions = "No major epidemic outbreaks; Government health spending maintained; Climate-related health risks manageable",
      purpose_narrative = "Increased immunization coverage and uptake of essential maternal and child health services in target communities",
      purpose_ovi = "Full immunization coverage increases from 54% to 80% in target areas; ANC4+ coverage increases from 45% to 70%",
      purpose_mov = "Health facility records (HMIS); Coverage surveys; EPI monitoring data; Independent household surveys",
      purpose_assumptions = "Communities willing to utilize health services; No major vaccine supply disruptions nationally; Health policy environment remains supportive",
      outputs = list(
        list(
          narrative = "Output 1: Community health workers trained and deployed with adequate supplies and supervision",
          ovi = "200 CHWs trained and certified; 90% of CHWs active with monthly reporting rates above 85%",
          mov = "Training records and certificates; CHW deployment records; Monthly activity reports; Supervisory visit reports",
          assumptions = "CHW attrition rate stays below 15%; Community acceptance of CHWs; Adequate supply of essential medicines maintained",
          activities = list(
            list(
              narrative = "Activity 1.1: Conduct CHW training programs covering IMNCI, immunization, and nutrition counseling",
              ovi = "8 training cohorts completed; 200 CHWs pass competency assessment with minimum 75% score",
              mov = "Training curriculum and schedule; Attendance registers; Competency assessment results; Training evaluation reports",
              assumptions = "Suitable candidates identified by communities; Training venues and materials available; Master trainers available"
            ),
            list(
              narrative = "Activity 1.2: Procure and distribute CHW kits, essential medicines, and reporting tools",
              ovi = "200 CHW kits procured and distributed; Quarterly resupply maintained for 90% of CHWs",
              mov = "Procurement records; Distribution lists; Stock management records; CHW kit inventory checks",
              assumptions = "Procurement processes not delayed; Supply chain to last mile functional; Storage conditions adequate"
            )
          )
        ),
        list(
          narrative = "Output 2: Cold chain infrastructure strengthened and vaccine management improved at health facility level",
          ovi = "50 health facilities equipped with functional cold chain equipment; Vaccine wastage rate reduced from 25% to below 10%",
          mov = "Cold chain equipment inventory; Temperature monitoring logs; Vaccine stock records; Facility assessment reports",
          assumptions = "Electricity/solar power reliable; Spare parts available for maintenance; Staff trained in cold chain management",
          activities = list(
            list(
              narrative = "Activity 2.1: Install solar-powered vaccine refrigerators in health facilities without reliable cold chain",
              ovi = "50 solar refrigerators installed and functional; Temperature maintained at 2-8 degrees C in 95% of monthly checks",
              mov = "Installation reports; Temperature monitoring records; Equipment maintenance logs; Supplier warranties",
              assumptions = "Solar equipment suppliers deliver on time; Facilities have appropriate space; Technical support available for installation"
            ),
            list(
              narrative = "Activity 2.2: Conduct IEC campaigns on immunization and maternal health in target communities",
              ovi = "100 community sensitization events held; Radio messages aired 3x daily for 6 months; 70% of caregivers aware of immunization schedule",
              mov = "IEC event reports and attendance; Radio airtime receipts; KAP survey results; Community feedback records",
              assumptions = "Communities receptive to messaging; Radio coverage adequate in target areas; No conflicting misinformation campaigns"
            )
          )
        )
      )
    ),
    "Agriculture" = list(
      goal_narrative = "Improved food security and rural livelihoods for smallholder farming households in target areas",
      goal_ovi = "Prevalence of food insecurity among target households reduced by 30% within 5 years; Average household income from agriculture increases by 40%",
      goal_mov = "Food security assessments (IPC/CARI); Household income and expenditure surveys; National agricultural statistics",
      goal_assumptions = "No severe climate shocks (drought/floods); Market access routes remain functional; National agricultural policies supportive",
      purpose_narrative = "Increased agricultural productivity and market participation among smallholder farmers in target districts",
      purpose_ovi = "Average crop yields increase by 50% for target crops; 60% of target farmers selling surplus at market (up from 25%)",
      purpose_mov = "Crop cutting surveys; Market transaction records; Farmer household surveys; Agricultural extension reports",
      purpose_assumptions = "Farmers adopt promoted technologies; Input prices remain affordable; Market prices do not collapse due to oversupply",
      outputs = list(
        list(
          narrative = "Output 1: Farmers trained in climate-smart agricultural practices and improved crop management",
          ovi = "3,000 farmers trained (40% women); 70% of trained farmers adopting at least 3 promoted practices",
          mov = "Training attendance records; Adoption surveys; Field monitoring reports; Farmer demonstration plot records",
          assumptions = "Farmers available during training periods; Extension workers able to provide follow-up; Demonstration plots accessible",
          activities = list(
            list(
              narrative = "Activity 1.1: Establish farmer field schools and demonstration plots in each target sub-county",
              ovi = "30 farmer field schools established with demonstration plots; Weekly sessions held over two growing seasons",
              mov = "FFS registration records; Session attendance and reports; Demonstration plot monitoring data; Photographic records",
              assumptions = "Land available for demonstration plots; Lead farmers willing to host; Inputs for demonstration plots procured on time"
            ),
            list(
              narrative = "Activity 1.2: Distribute improved seed varieties and organic inputs to participating farmers",
              ovi = "3,000 farmers receive improved seed packages; 2,000 farmers receive organic fertilizer starter kits",
              mov = "Input distribution records; Beneficiary receipts; Seed certification documents; Post-distribution monitoring",
              assumptions = "Certified seed available in sufficient quantities; Distribution logistics feasible; Farmers have land prepared for planting"
            )
          )
        ),
        list(
          narrative = "Output 2: Farmer cooperatives strengthened and linked to profitable market channels",
          ovi = "15 cooperatives registered and operational; Collective marketing volumes increase by 200%",
          mov = "Cooperative registration certificates; Marketing records and sales receipts; Cooperative financial audits; Member satisfaction surveys",
          assumptions = "Farmers willing to engage in collective action; Market buyers willing to contract with cooperatives; Transport infrastructure adequate",
          activities = list(
            list(
              narrative = "Activity 2.1: Support cooperative formation, governance training, and business plan development",
              ovi = "15 cooperatives formed with elected leadership; All cooperatives have approved business plans and financial systems",
              mov = "Cooperative constitution documents; Training records; Business plans; Financial management system records",
              assumptions = "Community cohesion sufficient for collective organization; No political interference in cooperative governance"
            ),
            list(
              narrative = "Activity 2.2: Facilitate market linkages and negotiate buyer contracts for cooperative produce",
              ovi = "10 buyer contracts signed with cooperatives; 3 market access points established with storage facilities",
              mov = "Signed buyer contracts; Market transaction records; Storage facility completion reports; Price monitoring data",
              assumptions = "Buyers interested in sourcing from smallholder cooperatives; Produce meets quality standards; Contract terms fair and enforceable"
            )
          )
        )
      )
    ),
    "WASH" = list(
      goal_narrative = "Improved public health outcomes through reduced waterborne disease burden in target communities",
      goal_ovi = "Incidence of diarrheal disease in children under 5 reduced by 40% in target communities; Stunting prevalence reduced by 15%",
      goal_mov = "Health facility morbidity data; DHS/MICS surveys; Community health surveillance records; WASH sector performance reports",
      goal_assumptions = "No major flooding or contamination events; Health sector continues complementary interventions; Population growth manageable",
      purpose_narrative = "Increased access to and sustained use of safe water, improved sanitation, and hygiene practices in target communities",
      purpose_ovi = "80% of target population using safely managed drinking water (up from 35%); Open defecation reduced from 45% to below 5%",
      purpose_mov = "WASH baseline and endline surveys; JMP monitoring data; Water quality testing results; Community-led total sanitation verification records",
      purpose_assumptions = "Communities willing to change hygiene behaviors; Water sources sustainable year-round; Local government maintains infrastructure",
      outputs = list(
        list(
          narrative = "Output 1: Safe water supply systems constructed and functional in target communities",
          ovi = "40 boreholes drilled and equipped with hand pumps; 10 gravity-fed piped water systems constructed; All systems delivering water meeting WHO standards",
          mov = "Borehole drilling logs and pump test results; Water quality test certificates; Construction completion reports; Community water committee records",
          assumptions = "Groundwater available at viable depths; Geological conditions suitable; Communities contribute agreed co-financing; Spare parts supply chain functional",
          activities = list(
            list(
              narrative = "Activity 1.1: Conduct hydrogeological surveys and drill boreholes in target communities",
              ovi = "50 sites surveyed; 40 boreholes successfully drilled with minimum yield of 0.5 liters/second",
              mov = "Hydrogeological survey reports; Drilling logs; Pump test results; GPS coordinates and site photos",
              assumptions = "Drilling equipment available; Access roads passable; Drilling contractors deliver on schedule"
            ),
            list(
              narrative = "Activity 1.2: Train community water committees in operation and maintenance of water systems",
              ovi = "50 water committees trained (min 50% women members); All committees collecting user fees and maintaining reserve funds",
              mov = "Training records; Committee meeting minutes; Financial records; Functionality monitoring reports",
              assumptions = "Community members willing to volunteer; Fee collection culturally acceptable; Technical skills retained after training"
            )
          )
        ),
        list(
          narrative = "Output 2: Improved sanitation facilities constructed and communities declared open-defecation free",
          ovi = "5,000 household latrines constructed; 20 communities verified as open-defecation free (ODF)",
          mov = "Latrine construction records; ODF verification reports; Household surveys; Environmental health inspection reports",
          assumptions = "Households invest in latrine construction with subsidy support; Soil conditions suitable; ODF status sustained after verification",
          activities = list(
            list(
              narrative = "Activity 2.1: Implement Community-Led Total Sanitation (CLTS) triggering in target villages",
              ovi = "40 CLTS triggering events conducted; 85% of triggered communities develop sanitation action plans",
              mov = "CLTS triggering reports; Community action plans; Follow-up monitoring reports; Natural leader identification records",
              assumptions = "Trained CLTS facilitators available; Community leaders supportive; Cultural barriers to behavior change addressable"
            ),
            list(
              narrative = "Activity 2.2: Conduct hygiene promotion campaigns focusing on handwashing and safe water storage",
              ovi = "60 hygiene promotion sessions conducted in schools and communities; Handwashing with soap at critical times increases from 15% to 60%",
              mov = "Session reports and attendance; Structured observation surveys; KAP survey results; School WASH monitoring records",
              assumptions = "Soap and hygiene supplies affordable and available locally; Schools integrate hygiene into routine; Messaging culturally appropriate"
            )
          )
        )
      )
    ),
    "Governance" = list(
      goal_narrative = "Strengthened democratic governance and improved public service delivery in target regions",
      goal_ovi = "Citizen satisfaction with public services increases by 25%; Governance index score improves by 15% in target areas",
      goal_mov = "Citizen perception surveys; Governance assessments (Mo Ibrahim/WGI); Public expenditure tracking surveys; National audit reports",
      goal_assumptions = "Political will for reform sustained; No major political instability; Donor coordination maintained",
      purpose_narrative = "Enhanced transparency, accountability, and citizen participation in local government processes",
      purpose_ovi = "75% of target local governments publish budgets publicly (up from 20%); Citizen participation in planning processes doubles",
      purpose_mov = "Local government budget publications; Participation records from planning meetings; Social audit reports; CSO monitoring reports",
      purpose_assumptions = "Legal framework supports decentralization; Local officials willing to engage; Citizens empowered to participate without fear of reprisal",
      outputs = list(
        list(
          narrative = "Output 1: Local government officials trained in transparent financial management and participatory planning",
          ovi = "150 local officials trained in PFM; 80% of target local governments adopt participatory budgeting processes",
          mov = "Training records and certificates; PFM assessment scores; Participatory budgeting documentation; Audit reports",
          assumptions = "Officials attend and complete training; Institutional incentives align with reform; Staff turnover manageable",
          activities = list(
            list(
              narrative = "Activity 1.1: Design and deliver public financial management training for local government staff",
              ovi = "6 training modules developed and delivered; 150 officials complete full certification program",
              mov = "Training curriculum; Attendance records; Pre/post assessments; Certification records; Training evaluation reports",
              assumptions = "Training content contextually relevant; Officials released from duties to attend; Budget available for all planned cohorts"
            ),
            list(
              narrative = "Activity 1.2: Support implementation of participatory budgeting in target local governments",
              ovi = "20 local governments conduct participatory budget hearings; Citizen proposals integrated into 70% of approved budgets",
              mov = "Budget hearing records and minutes; Budget documents showing citizen input; Participant registers; Process evaluation reports",
              assumptions = "Citizens motivated to participate; Local governments allocate resources for participatory processes; Civil society organizations provide facilitation support"
            )
          )
        ),
        list(
          narrative = "Output 2: Civil society organizations strengthened to perform oversight and advocacy functions",
          ovi = "30 CSOs receive capacity building support; 20 CSOs conducting regular budget monitoring and social audits",
          mov = "CSO capacity assessment reports; Social audit reports; Budget tracking publications; Media coverage of CSO activities",
          assumptions = "Civic space not restricted by new legislation; CSOs willing to engage constructively; Funding sustained for CSO activities",
          activities = list(
            list(
              narrative = "Activity 2.1: Conduct organizational capacity assessments and deliver tailored CSO strengthening programs",
              ovi = "30 CSO capacity assessments completed; Tailored capacity building plans implemented for each CSO; Average capacity scores improve by 40%",
              mov = "Capacity assessment reports (baseline and follow-up); Training records; Organizational development plans; Mentoring session records",
              assumptions = "CSOs committed to organizational development; Qualified capacity building providers available; Assessment tools culturally appropriate"
            ),
            list(
              narrative = "Activity 2.2: Establish citizen feedback mechanisms and community scorecards for public services",
              ovi = "20 community scorecard processes completed; 15 citizen feedback platforms operational; 60% of identified service delivery issues addressed by local government",
              mov = "Scorecard process reports; Feedback platform usage data; Interface meeting records; Service improvement tracking records",
              assumptions = "Service providers willing to respond to citizen feedback; Communities trust the feedback mechanism; Local media supports dissemination of findings"
            )
          )
        )
      )
    )
  )
  return(templates[[template_name]])
}

# =============================================================================
# COLOR THEMES
# =============================================================================

get_theme_css <- function(theme_name) {
  themes <- list(
    "Default" = list(
      primary = "#2C3E50",
      secondary = "#18BC9C",
      accent = "#3498DB",
      bg_light = "#F8F9FA",
      bg_sidebar = "#2C3E50",
      text_sidebar = "#ECF0F1",
      header_bg = "#18BC9C",
      header_text = "#FFFFFF",
      goal_color = "#1A5276",
      purpose_color = "#1A6B4F",
      output_color = "#7D6608",
      activity_color = "#6C3483",
      progress_bar = "#18BC9C",
      border_color = "#DEE2E6"
    ),
    "USAID" = list(
      primary = "#002F6C",
      secondary = "#BA0C2F",
      accent = "#0067B9",
      bg_light = "#F5F5F5",
      bg_sidebar = "#002F6C",
      text_sidebar = "#FFFFFF",
      header_bg = "#BA0C2F",
      header_text = "#FFFFFF",
      goal_color = "#002F6C",
      purpose_color = "#BA0C2F",
      output_color = "#0067B9",
      activity_color = "#651D32",
      progress_bar = "#BA0C2F",
      border_color = "#CCCCCC"
    ),
    "DFID" = list(
      primary = "#1D70B8",
      secondary = "#00703C",
      accent = "#F47738",
      bg_light = "#F3F2F1",
      bg_sidebar = "#0B0C0C",
      text_sidebar = "#FFFFFF",
      header_bg = "#1D70B8",
      header_text = "#FFFFFF",
      goal_color = "#1D70B8",
      purpose_color = "#00703C",
      output_color = "#F47738",
      activity_color = "#912B88",
      progress_bar = "#00703C",
      border_color = "#B1B4B6"
    ),
    "World Bank" = list(
      primary = "#002244",
      secondary = "#F4A100",
      accent = "#009FDA",
      bg_light = "#F7F7F7",
      bg_sidebar = "#002244",
      text_sidebar = "#FFFFFF",
      header_bg = "#F4A100",
      header_text = "#002244",
      goal_color = "#002244",
      purpose_color = "#F4A100",
      output_color = "#009FDA",
      activity_color = "#00AB51",
      progress_bar = "#F4A100",
      border_color = "#DDDDDD"
    )
  )
  return(themes[[theme_name]])
}

build_css <- function(theme) {
  sprintf('
    /* ---- Global ---- */
    body {
      font-family: "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
      background-color: %s;
      color: #333333;
    }

    /* ---- Sidebar ---- */
    .well {
      background-color: %s !important;
      color: %s !important;
      border: none !important;
      border-radius: 8px;
      box-shadow: 0 2px 10px rgba(0,0,0,0.15);
    }
    .well label {
      color: %s !important;
      font-weight: 500;
    }
    .well .control-label {
      color: %s !important;
    }
    .well .btn {
      width: 100%%;
      margin-bottom: 8px;
      border-radius: 5px;
      font-weight: 600;
      transition: all 0.2s;
    }
    .well .btn:hover {
      transform: translateY(-1px);
      box-shadow: 0 2px 8px rgba(0,0,0,0.2);
    }

    /* ---- Title ---- */
    .app-title {
      background: linear-gradient(135deg, %s, %s);
      color: %s;
      padding: 18px 25px;
      margin: -15px -15px 20px -15px;
      border-radius: 8px;
      font-size: 26px;
      font-weight: 700;
      letter-spacing: 0.5px;
      box-shadow: 0 3px 12px rgba(0,0,0,0.12);
    }
    .app-title small {
      font-size: 13px;
      opacity: 0.9;
      display: block;
      margin-top: 4px;
      font-weight: 400;
      letter-spacing: 1px;
    }

    /* ---- Tabs ---- */
    .nav-tabs {
      border-bottom: 3px solid %s;
      margin-bottom: 20px;
    }
    .nav-tabs > li > a {
      color: #555;
      font-weight: 600;
      border-radius: 5px 5px 0 0;
      padding: 10px 18px;
      transition: all 0.2s;
    }
    .nav-tabs > li.active > a,
    .nav-tabs > li.active > a:hover,
    .nav-tabs > li.active > a:focus {
      color: %s;
      border-bottom: 3px solid %s;
      background-color: white;
      font-weight: 700;
    }
    .nav-tabs > li > a:hover {
      background-color: rgba(0,0,0,0.03);
    }

    /* ---- LogFrame Matrix ---- */
    .logframe-section {
      margin-bottom: 20px;
      border-radius: 8px;
      overflow: hidden;
      box-shadow: 0 2px 8px rgba(0,0,0,0.08);
      border: 1px solid %s;
    }
    .logframe-header {
      padding: 12px 18px;
      font-weight: 700;
      font-size: 15px;
      letter-spacing: 0.3px;
    }
    .logframe-goal-header { background-color: %s; color: white; }
    .logframe-purpose-header { background-color: %s; color: white; }
    .logframe-output-header { background-color: %s; color: white; }
    .logframe-activity-header { background-color: %s; color: white; }

    .logframe-row {
      display: flex;
      border-bottom: 1px solid %s;
    }
    .logframe-row:last-child { border-bottom: none; }
    .logframe-cell {
      flex: 1;
      padding: 10px 12px;
      border-right: 1px solid %s;
    }
    .logframe-cell:last-child { border-right: none; }
    .logframe-cell label {
      font-size: 11px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      color: #666 !important;
      margin-bottom: 4px;
    }
    .logframe-cell textarea {
      width: 100%%;
      border: 1px solid %s;
      border-radius: 4px;
      padding: 8px;
      font-size: 13px;
      resize: vertical;
      min-height: 70px;
      transition: border-color 0.2s;
    }
    .logframe-cell textarea:focus {
      border-color: %s;
      outline: none;
      box-shadow: 0 0 0 2px rgba(0,0,0,0.05);
    }

    /* ---- Indicator Tracker ---- */
    .indicator-table {
      width: 100%%;
      border-collapse: collapse;
      margin-bottom: 20px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.08);
      border-radius: 8px;
      overflow: hidden;
    }
    .indicator-table th {
      background-color: %s;
      color: %s;
      padding: 12px 15px;
      text-align: left;
      font-weight: 600;
      font-size: 13px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .indicator-table td {
      padding: 10px 12px;
      border-bottom: 1px solid %s;
      vertical-align: middle;
    }
    .indicator-table tr:hover td {
      background-color: rgba(0,0,0,0.02);
    }
    .indicator-table input[type="number"],
    .indicator-table input[type="text"] {
      width: 100%%;
      border: 1px solid %s;
      border-radius: 4px;
      padding: 6px 8px;
      font-size: 13px;
    }
    .progress-container {
      background-color: #E9ECEF;
      border-radius: 10px;
      height: 22px;
      overflow: hidden;
      position: relative;
    }
    .progress-fill {
      height: 100%%;
      border-radius: 10px;
      background: linear-gradient(90deg, %s, %s);
      transition: width 0.5s ease;
      min-width: 0;
    }
    .progress-text {
      position: absolute;
      top: 50%%;
      left: 50%%;
      transform: translate(-50%%, -50%%);
      font-size: 11px;
      font-weight: 700;
      color: #333;
    }

    /* ---- Results Chain ---- */
    .results-chain-container {
      display: flex;
      flex-direction: column;
      align-items: center;
      padding: 30px 20px;
      gap: 0;
    }
    .chain-level {
      width: 90%%;
      max-width: 800px;
      border-radius: 10px;
      padding: 18px 24px;
      text-align: center;
      color: white;
      box-shadow: 0 3px 10px rgba(0,0,0,0.12);
      position: relative;
    }
    .chain-level h4 {
      margin: 0 0 6px 0;
      font-size: 14px;
      text-transform: uppercase;
      letter-spacing: 1px;
      opacity: 0.9;
    }
    .chain-level p {
      margin: 0;
      font-size: 15px;
      font-weight: 500;
      line-height: 1.4;
    }
    .chain-arrow {
      font-size: 30px;
      color: #AAB7C4;
      line-height: 1;
      padding: 4px 0;
    }
    .chain-sub-items {
      display: flex;
      flex-wrap: wrap;
      gap: 12px;
      justify-content: center;
      width: 90%%;
      max-width: 900px;
    }
    .chain-sub-item {
      flex: 1;
      min-width: 200px;
      max-width: 350px;
      border-radius: 8px;
      padding: 14px 18px;
      color: white;
      box-shadow: 0 2px 8px rgba(0,0,0,0.1);
      text-align: center;
    }
    .chain-sub-item h5 {
      margin: 0 0 4px 0;
      font-size: 12px;
      text-transform: uppercase;
      letter-spacing: 0.8px;
      opacity: 0.85;
    }
    .chain-sub-item p {
      margin: 0;
      font-size: 13px;
      line-height: 1.3;
    }

    /* ---- Export Preview ---- */
    .preview-container {
      background: white;
      padding: 40px;
      border: 1px solid %s;
      box-shadow: 0 2px 12px rgba(0,0,0,0.06);
      border-radius: 6px;
      max-width: 1000px;
      margin: 0 auto;
    }
    .preview-title {
      font-size: 24px;
      font-weight: 700;
      color: %s;
      border-bottom: 3px solid %s;
      padding-bottom: 10px;
      margin-bottom: 20px;
    }
    .preview-table {
      width: 100%%;
      border-collapse: collapse;
      margin-bottom: 25px;
      font-size: 13px;
    }
    .preview-table th {
      background-color: %s;
      color: %s;
      padding: 10px 14px;
      text-align: left;
      font-weight: 600;
      font-size: 12px;
      text-transform: uppercase;
    }
    .preview-table td {
      padding: 10px 14px;
      border: 1px solid %s;
      vertical-align: top;
      line-height: 1.5;
    }
    .preview-level-label {
      font-weight: 700;
      writing-mode: vertical-rl;
      text-orientation: mixed;
      text-align: center;
      width: 35px;
      padding: 10px 5px !important;
      letter-spacing: 1px;
      font-size: 11px;
    }

    /* ---- About ---- */
    .about-section {
      background: white;
      padding: 30px;
      border-radius: 8px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.06);
      margin-bottom: 20px;
      line-height: 1.7;
    }
    .about-section h3 {
      color: %s;
      border-bottom: 2px solid %s;
      padding-bottom: 8px;
      margin-top: 0;
    }
    .about-section h4 {
      color: %s;
      margin-top: 18px;
    }
    .about-section ul { padding-left: 20px; }
    .about-section li { margin-bottom: 6px; }
    .about-section .reference {
      font-size: 13px;
      color: #666;
      padding-left: 20px;
      text-indent: -20px;
      margin-bottom: 6px;
    }
    .smart-table {
      width: 100%%;
      border-collapse: collapse;
      margin: 15px 0;
    }
    .smart-table th, .smart-table td {
      padding: 10px 14px;
      border: 1px solid %s;
      text-align: left;
    }
    .smart-table th {
      background-color: %s;
      color: %s;
      font-weight: 600;
    }

    /* ---- Download buttons ---- */
    .btn-csv { background-color: %s !important; color: white !important; border: none !important; }
    .btn-html-report { background-color: %s !important; color: %s !important; border: none !important; }

    /* ---- Misc ---- */
    .section-divider {
      border: none;
      border-top: 2px dashed %s;
      margin: 15px 0;
    }
    .help-text {
      font-size: 11px;
      color: rgba(255,255,255,0.7);
      margin-top: 2px;
    }
  ',
    theme$bg_light,
    theme$bg_sidebar, theme$text_sidebar,
    theme$text_sidebar, theme$text_sidebar,
    theme$primary, theme$secondary, theme$header_text,
    theme$secondary, theme$primary, theme$secondary,
    theme$border_color,
    theme$goal_color, theme$purpose_color, theme$output_color, theme$activity_color,
    theme$border_color, theme$border_color, theme$border_color,
    theme$accent,
    theme$primary, theme$header_text, theme$border_color, theme$border_color,
    theme$secondary, theme$accent,
    theme$border_color, theme$primary, theme$secondary,
    theme$primary, theme$header_text, theme$border_color,
    theme$primary, theme$secondary, theme$primary,
    theme$border_color,
    theme$primary, theme$header_text,
    theme$border_color, theme$primary, theme$header_text,
    theme$secondary, theme$accent, theme$header_text,
    theme$border_color
  )
}


# =============================================================================
# UI
# =============================================================================

ui <- fluidPage(
  tags$head(
    tags$style(HTML("/* Dynamic CSS injected via server */"))
  ),
  uiOutput("dynamic_css"),
  div(class = "app-title",
      "LogFrame Builder",
      tags$small("IMPACT MOJO — Logical Framework Design & Monitoring Tool")
  ),
  sidebarLayout(
    sidebarPanel(
      width = 3,
      textInput("project_name", "Project Name", value = "My Development Project"),
      hr(class = "section-divider"),
      selectInput("template", "Template",
                  choices = c("Blank", "Education", "Health", "Agriculture", "WASH", "Governance"),
                  selected = "Blank"),
      p(class = "help-text", "Select a sector template to auto-populate example content"),
      hr(class = "section-divider"),
      sliderInput("num_outcomes", "Number of Outcomes", min = 1, max = 5, value = 2, step = 1),
      sliderInput("num_outputs", "Outputs per Outcome", min = 1, max = 5, value = 2, step = 1),
      sliderInput("num_activities", "Activities per Output", min = 1, max = 5, value = 2, step = 1),
      hr(class = "section-divider"),
      selectInput("color_theme", "Color Theme",
                  choices = c("Default", "USAID", "DFID", "World Bank"),
                  selected = "Default"),
      hr(class = "section-divider"),
      downloadButton("download_csv", "Export as CSV", class = "btn-csv"),
      downloadButton("download_html", "Export as HTML Report", class = "btn-html-report")
    ),
    mainPanel(
      width = 9,
      tabsetPanel(
        id = "main_tabs",
        tabPanel("LogFrame Matrix", uiOutput("logframe_matrix_ui")),
        tabPanel("Indicator Tracker", uiOutput("indicator_tracker_ui")),
        tabPanel("Results Chain", uiOutput("results_chain_ui")),
        tabPanel("Export Preview", uiOutput("export_preview_ui")),
        tabPanel("About", uiOutput("about_ui"))
      )
    )
  )
)


# =============================================================================
# SERVER
# =============================================================================

server <- function(input, output, session) {

  # ---------- Reactive: current theme ----------
  current_theme <- reactive({
    get_theme_css(input$color_theme)
  })

  output$dynamic_css <- renderUI({
    tags$style(HTML(build_css(current_theme())))
  })

  # ---------- Template application ----------
  observeEvent(input$template, {
    tmpl <- get_template(input$template)
    if (is.null(tmpl)) return()

    updateTextAreaInput(session, "goal_narrative", value = tmpl$goal_narrative)
    updateTextAreaInput(session, "goal_ovi", value = tmpl$goal_ovi)
    updateTextAreaInput(session, "goal_mov", value = tmpl$goal_mov)
    updateTextAreaInput(session, "goal_assumptions", value = tmpl$goal_assumptions)

    updateTextAreaInput(session, "purpose_narrative_1", value = tmpl$purpose_narrative)
    updateTextAreaInput(session, "purpose_ovi_1", value = tmpl$purpose_ovi)
    updateTextAreaInput(session, "purpose_mov_1", value = tmpl$purpose_mov)
    updateTextAreaInput(session, "purpose_assumptions_1", value = tmpl$purpose_assumptions)

    # Clear other outcomes
    for (oc in 2:5) {
      updateTextAreaInput(session, paste0("purpose_narrative_", oc), value = "")
      updateTextAreaInput(session, paste0("purpose_ovi_", oc), value = "")
      updateTextAreaInput(session, paste0("purpose_mov_", oc), value = "")
      updateTextAreaInput(session, paste0("purpose_assumptions_", oc), value = "")
    }

    # Populate outputs and activities
    for (oc_i in 1:5) {
      for (op_i in 1:5) {
        tmpl_output <- NULL
        if (oc_i == 1 && op_i <= length(tmpl$outputs)) {
          tmpl_output <- tmpl$outputs[[op_i]]
        }
        out_prefix <- paste0("output_", oc_i, "_", op_i, "_")
        updateTextAreaInput(session, paste0(out_prefix, "narrative"), value = if (!is.null(tmpl_output)) tmpl_output$narrative else "")
        updateTextAreaInput(session, paste0(out_prefix, "ovi"), value = if (!is.null(tmpl_output)) tmpl_output$ovi else "")
        updateTextAreaInput(session, paste0(out_prefix, "mov"), value = if (!is.null(tmpl_output)) tmpl_output$mov else "")
        updateTextAreaInput(session, paste0(out_prefix, "assumptions"), value = if (!is.null(tmpl_output)) tmpl_output$assumptions else "")

        for (ac_i in 1:5) {
          tmpl_activity <- NULL
          if (!is.null(tmpl_output) && ac_i <= length(tmpl_output$activities)) {
            tmpl_activity <- tmpl_output$activities[[ac_i]]
          }
          act_prefix <- paste0("activity_", oc_i, "_", op_i, "_", ac_i, "_")
          updateTextAreaInput(session, paste0(act_prefix, "narrative"), value = if (!is.null(tmpl_activity)) tmpl_activity$narrative else "")
          updateTextAreaInput(session, paste0(act_prefix, "ovi"), value = if (!is.null(tmpl_activity)) tmpl_activity$ovi else "")
          updateTextAreaInput(session, paste0(act_prefix, "mov"), value = if (!is.null(tmpl_activity)) tmpl_activity$mov else "")
          updateTextAreaInput(session, paste0(act_prefix, "assumptions"), value = if (!is.null(tmpl_activity)) tmpl_activity$assumptions else "")
        }
      }
    }
  })

  # ---------- Helper: create a 4-cell logframe row ----------
  make_logframe_row <- function(prefix, narrative_label = "Narrative Summary") {
    div(class = "logframe-row",
        div(class = "logframe-cell",
            tags$label(narrative_label),
            tags$textarea(id = paste0(prefix, "narrative"), class = "form-control shiny-bound-input",
                          rows = 3, placeholder = "Enter narrative summary...")
        ),
        div(class = "logframe-cell",
            tags$label("Objectively Verifiable Indicators"),
            tags$textarea(id = paste0(prefix, "ovi"), class = "form-control shiny-bound-input",
                          rows = 3, placeholder = "Enter OVIs...")
        ),
        div(class = "logframe-cell",
            tags$label("Means of Verification"),
            tags$textarea(id = paste0(prefix, "mov"), class = "form-control shiny-bound-input",
                          rows = 3, placeholder = "Enter MoV...")
        ),
        div(class = "logframe-cell",
            tags$label("Assumptions / Risks"),
            tags$textarea(id = paste0(prefix, "assumptions"), class = "form-control shiny-bound-input",
                          rows = 3, placeholder = "Enter assumptions and risks...")
        )
    )
  }

  # ---------- TAB 1: LogFrame Matrix ----------
  output$logframe_matrix_ui <- renderUI({
    theme <- current_theme()
    n_outcomes <- input$num_outcomes
    n_outputs <- input$num_outputs
    n_activities <- input$num_activities

    goal_section <- div(class = "logframe-section",
                        div(class = "logframe-header logframe-goal-header",
                            icon("bullseye"), " GOAL / IMPACT"),
                        make_logframe_row("goal_")
    )

    outcome_sections <- lapply(1:n_outcomes, function(oc) {
      oc_prefix <- paste0("purpose_")

      output_sections <- lapply(1:n_outputs, function(op) {
        op_prefix <- paste0("output_", oc, "_", op, "_")

        activity_sections <- lapply(1:n_activities, function(ac) {
          ac_prefix <- paste0("activity_", oc, "_", op, "_", ac, "_")
          div(class = "logframe-section",
              div(class = "logframe-header logframe-activity-header",
                  icon("tasks"), sprintf(" ACTIVITY %d.%d.%d", oc, op, ac)),
              make_logframe_row(ac_prefix)
          )
        })

        tagList(
          div(class = "logframe-section",
              div(class = "logframe-header logframe-output-header",
                  icon("cube"), sprintf(" OUTPUT %d.%d", oc, op)),
              make_logframe_row(op_prefix)
          ),
          activity_sections
        )
      })

      tagList(
        div(class = "logframe-section",
            div(class = "logframe-header logframe-purpose-header",
                icon("crosshairs"), sprintf(" OUTCOME %d (PURPOSE)", oc)),
            make_logframe_row(paste0("purpose_", oc, "_"))  # outcome-specific prefix
        ),
        output_sections
      )
    })

    tagList(
      h3(icon("th"), " Logical Framework Matrix",
         style = sprintf("color: %s; margin-bottom: 20px;", theme$primary)),
      p(style = "color: #666; margin-bottom: 20px;",
        "Fill in each cell below. The matrix follows the classic 4-level logframe structure. ",
        "Each level includes Narrative Summary, Objectively Verifiable Indicators (OVIs), ",
        "Means of Verification (MoV), and Assumptions/Risks."),
      goal_section,
      outcome_sections
    )
  })

  # ---------- Helper: safely read a textarea ----------
  get_val <- function(id) {
    val <- input[[id]]
    if (is.null(val)) "" else val
  }

  # ---------- TAB 2: Indicator Tracker ----------
  output$indicator_tracker_ui <- renderUI({
    theme <- current_theme()
    n_outcomes <- input$num_outcomes
    n_outputs <- input$num_outputs

    # Gather OVIs from all levels
    indicators <- list()

    # Goal OVI
    goal_ovi <- get_val("goal_ovi")
    if (nchar(trimws(goal_ovi)) > 0) {
      indicators[[length(indicators) + 1]] <- list(
        level = "Goal", label = "Goal", id_prefix = "ind_goal_", ovi = goal_ovi)
    }

    for (oc in 1:n_outcomes) {
      oc_ovi <- get_val(paste0("purpose_", oc, "_ovi"))
      if (nchar(trimws(oc_ovi)) > 0) {
        indicators[[length(indicators) + 1]] <- list(
          level = "Outcome", label = paste("Outcome", oc),
          id_prefix = paste0("ind_oc_", oc, "_"), ovi = oc_ovi)
      }
      for (op in 1:n_outputs) {
        op_ovi <- get_val(paste0("output_", oc, "_", op, "_ovi"))
        if (nchar(trimws(op_ovi)) > 0) {
          indicators[[length(indicators) + 1]] <- list(
            level = "Output", label = paste0("Output ", oc, ".", op),
            id_prefix = paste0("ind_op_", oc, "_", op, "_"), ovi = op_ovi)
        }
      }
    }

    if (length(indicators) == 0) {
      return(tagList(
        h3(icon("chart-bar"), " Indicator Tracker",
           style = sprintf("color: %s; margin-bottom: 20px;", theme$primary)),
        div(class = "about-section",
            p(style = "color: #888; font-style: italic;",
              "No indicators found. Please fill in Objectively Verifiable Indicators (OVIs) ",
              "in the LogFrame Matrix tab to populate this tracker."))
      ))
    }

    header_row <- tags$tr(
      tags$th("Level"),
      tags$th("Indicator (OVI)", style = "min-width: 200px;"),
      tags$th("Baseline", style = "width: 90px;"),
      tags$th("Midline Target", style = "width: 90px;"),
      tags$th("Midline Actual", style = "width: 90px;"),
      tags$th("Endline Target", style = "width: 90px;"),
      tags$th("Endline Actual", style = "width: 90px;"),
      tags$th("Progress", style = "width: 150px;")
    )

    data_rows <- lapply(seq_along(indicators), function(i) {
      ind <- indicators[[i]]
      pfx <- ind$id_prefix
      baseline_id <- paste0(pfx, "baseline")
      mid_target_id <- paste0(pfx, "mid_target")
      mid_actual_id <- paste0(pfx, "mid_actual")
      end_target_id <- paste0(pfx, "end_target")
      end_actual_id <- paste0(pfx, "end_actual")

      # Calculate progress
      end_target_val <- as.numeric(get_val(end_target_id))
      end_actual_val <- as.numeric(get_val(end_actual_id))
      baseline_val <- as.numeric(get_val(baseline_id))

      pct <- 0
      if (!is.na(end_target_val) && !is.na(baseline_val) && (end_target_val - baseline_val) != 0) {
        actual <- if (!is.na(end_actual_val)) end_actual_val else {
          mid_a <- as.numeric(get_val(mid_actual_id))
          if (!is.na(mid_a)) mid_a else baseline_val
        }
        pct <- round(((actual - baseline_val) / (end_target_val - baseline_val)) * 100, 1)
        pct <- max(0, min(pct, 100))
      }

      bar_color <- if (pct < 25) "#E74C3C" else if (pct < 50) "#F39C12" else if (pct < 75) "#3498DB" else theme$secondary

      level_bg <- switch(ind$level,
                         "Goal" = theme$goal_color,
                         "Outcome" = theme$purpose_color,
                         "Output" = theme$output_color,
                         theme$primary)

      tags$tr(
        tags$td(
          span(style = sprintf("background:%s; color:white; padding:3px 10px; border-radius:12px; font-size:11px; font-weight:600;", level_bg),
               ind$label)
        ),
        tags$td(style = "font-size: 12px;",
                substr(ind$ovi, 1, 120), if (nchar(ind$ovi) > 120) "..." else ""),
        tags$td(tags$input(type = "number", id = baseline_id, class = "form-control shiny-bound-input",
                           value = get_val(baseline_id), placeholder = "0")),
        tags$td(tags$input(type = "number", id = mid_target_id, class = "form-control shiny-bound-input",
                           value = get_val(mid_target_id), placeholder = "0")),
        tags$td(tags$input(type = "number", id = mid_actual_id, class = "form-control shiny-bound-input",
                           value = get_val(mid_actual_id), placeholder = "0")),
        tags$td(tags$input(type = "number", id = end_target_id, class = "form-control shiny-bound-input",
                           value = get_val(end_target_id), placeholder = "0")),
        tags$td(tags$input(type = "number", id = end_actual_id, class = "form-control shiny-bound-input",
                           value = get_val(end_actual_id), placeholder = "0")),
        tags$td(
          div(class = "progress-container",
              div(class = "progress-fill",
                  style = sprintf("width: %s%%; background: linear-gradient(90deg, %s, %s);", pct, bar_color, bar_color)),
              span(class = "progress-text", sprintf("%.0f%%", pct))
          )
        )
      )
    })

    tagList(
      h3(icon("chart-bar"), " Indicator Tracker",
         style = sprintf("color: %s; margin-bottom: 10px;", theme$primary)),
      p(style = "color: #666; margin-bottom: 20px;",
        "Track progress against your indicators. Enter numeric baseline, target, and actual values. ",
        "The progress bar shows percentage achieved toward the endline target."),
      tags$table(class = "indicator-table",
                 tags$thead(header_row),
                 tags$tbody(data_rows)
      )
    )
  })

  # ---------- TAB 3: Results Chain ----------
  output$results_chain_ui <- renderUI({
    theme <- current_theme()
    n_outcomes <- input$num_outcomes
    n_outputs <- input$num_outputs
    n_activities <- input$num_activities

    goal_text <- get_val("goal_narrative")
    if (nchar(trimws(goal_text)) == 0) goal_text <- "(Goal not yet defined)"

    # Build outcome items
    outcome_items <- lapply(1:n_outcomes, function(oc) {
      txt <- get_val(paste0("purpose_", oc, "_narrative"))
      if (nchar(trimws(txt)) == 0) txt <- paste0("(Outcome ", oc, " not yet defined)")
      div(class = "chain-sub-item",
          style = sprintf("background-color: %s;", theme$purpose_color),
          h5(paste("Outcome", oc)),
          p(substr(txt, 1, 150))
      )
    })

    # Build output items
    output_items <- list()
    for (oc in 1:n_outcomes) {
      for (op in 1:n_outputs) {
        txt <- get_val(paste0("output_", oc, "_", op, "_narrative"))
        if (nchar(trimws(txt)) == 0) txt <- paste0("(Output ", oc, ".", op, " not yet defined)")
        output_items[[length(output_items) + 1]] <- div(
          class = "chain-sub-item",
          style = sprintf("background-color: %s;", theme$output_color),
          h5(paste0("Output ", oc, ".", op)),
          p(substr(txt, 1, 120))
        )
      }
    }

    # Build activity items
    activity_items <- list()
    for (oc in 1:n_outcomes) {
      for (op in 1:n_outputs) {
        for (ac in 1:n_activities) {
          txt <- get_val(paste0("activity_", oc, "_", op, "_", ac, "_narrative"))
          if (nchar(trimws(txt)) == 0) txt <- paste0("(Activity ", oc, ".", op, ".", ac, ")")
          activity_items[[length(activity_items) + 1]] <- div(
            class = "chain-sub-item",
            style = sprintf("background-color: %s;", theme$activity_color),
            h5(paste0("Activity ", oc, ".", op, ".", ac)),
            p(substr(txt, 1, 100))
          )
        }
      }
    }

    tagList(
      h3(icon("project-diagram"), " Results Chain Visualization",
         style = sprintf("color: %s; margin-bottom: 10px;", theme$primary)),
      p(style = "color: #666; margin-bottom: 20px;",
        "Visual representation of the causal logic: Activities lead to Outputs, ",
        "which produce Outcomes, contributing to the overall Goal/Impact."),
      div(class = "results-chain-container",
          # Impact / Goal
          div(class = "chain-level",
              style = sprintf("background-color: %s;", theme$goal_color),
              h4("Goal / Impact"),
              p(substr(goal_text, 1, 200))
          ),
          div(class = "chain-arrow", HTML("&#9650;")),

          # Outcomes
          div(class = "chain-sub-items", outcome_items),
          div(class = "chain-arrow", HTML("&#9650;")),

          # Outputs
          div(class = "chain-sub-items", output_items),
          div(class = "chain-arrow", HTML("&#9650;")),

          # Activities
          div(class = "chain-sub-items", activity_items)
      )
    )
  })

  # ---------- TAB 4: Export Preview ----------
  output$export_preview_ui <- renderUI({
    theme <- current_theme()
    n_outcomes <- input$num_outcomes
    n_outputs <- input$num_outputs
    n_activities <- input$num_activities
    project <- input$project_name

    # Build preview table rows
    build_preview_row <- function(level_label, bg_color, narrative, ovi, mov, assumptions) {
      tags$tr(
        tags$td(class = "preview-level-label", style = sprintf("background: %s; color: white;", bg_color),
                level_label),
        tags$td(narrative),
        tags$td(ovi),
        tags$td(mov),
        tags$td(assumptions)
      )
    }

    goal_row <- build_preview_row(
      "GOAL", theme$goal_color,
      get_val("goal_narrative"), get_val("goal_ovi"),
      get_val("goal_mov"), get_val("goal_assumptions")
    )

    all_rows <- list(goal_row)

    for (oc in 1:n_outcomes) {
      all_rows[[length(all_rows) + 1]] <- build_preview_row(
        paste0("OUTCOME ", oc), theme$purpose_color,
        get_val(paste0("purpose_", oc, "_narrative")),
        get_val(paste0("purpose_", oc, "_ovi")),
        get_val(paste0("purpose_", oc, "_mov")),
        get_val(paste0("purpose_", oc, "_assumptions"))
      )

      for (op in 1:n_outputs) {
        pfx <- paste0("output_", oc, "_", op, "_")
        all_rows[[length(all_rows) + 1]] <- build_preview_row(
          paste0("OUTPUT ", oc, ".", op), theme$output_color,
          get_val(paste0(pfx, "narrative")),
          get_val(paste0(pfx, "ovi")),
          get_val(paste0(pfx, "mov")),
          get_val(paste0(pfx, "assumptions"))
        )

        for (ac in 1:n_activities) {
          apfx <- paste0("activity_", oc, "_", op, "_", ac, "_")
          all_rows[[length(all_rows) + 1]] <- build_preview_row(
            paste0("ACT ", oc, ".", op, ".", ac), theme$activity_color,
            get_val(paste0(apfx, "narrative")),
            get_val(paste0(apfx, "ovi")),
            get_val(paste0(apfx, "mov")),
            get_val(paste0(apfx, "assumptions"))
          )
        }
      }
    }

    tagList(
      h3(icon("file-alt"), " Export Preview",
         style = sprintf("color: %s; margin-bottom: 20px;", theme$primary)),
      div(class = "preview-container",
          div(class = "preview-title", project),
          p(style = "color: #888; margin-bottom: 20px; font-size: 13px;",
            sprintf("Logical Framework — Generated on %s", Sys.Date())),
          tags$table(class = "preview-table",
                     tags$thead(
                       tags$tr(
                         tags$th("Level", style = "width: 40px;"),
                         tags$th("Narrative Summary", style = "width: 28%;"),
                         tags$th("OVIs", style = "width: 24%;"),
                         tags$th("Means of Verification", style = "width: 24%;"),
                         tags$th("Assumptions / Risks", style = "width: 24%;")
                       )
                     ),
                     tags$tbody(all_rows)
          )
      )
    )
  })

  # ---------- TAB 5: About ----------
  output$about_ui <- renderUI({
    theme <- current_theme()

    tagList(
      div(class = "about-section",
          h3("What is a Logical Framework (LogFrame)?"),
          p("The Logical Framework Approach (LFA) is a systematic planning and management tool
            widely used in the design, monitoring, and evaluation of international development
            projects. It provides a structured format for specifying the components of a project
            or programme and the logical linkages between the different levels of objectives,
            planned activities, and expected results."),
          p("At its core, the LogFrame is presented as a 4x4 matrix that captures:"),
          tags$ul(
            tags$li(tags$strong("Rows (Vertical Logic):"), " Four hierarchical levels —
                    Goal/Impact, Purpose/Outcome, Outputs, and Activities — linked by
                    causal 'if-then' relationships."),
            tags$li(tags$strong("Columns (Horizontal Logic):"), " For each level —
                    Narrative Summary, Objectively Verifiable Indicators (OVIs),
                    Means of Verification (MoV), and Assumptions/Risks.")
          )
      ),

      div(class = "about-section",
          h3("Origins and Adoption"),
          p("The Logical Framework Approach has a rich history in international development:"),
          tags$ul(
            tags$li(tags$strong("1960s — USAID:"), " Originally developed by Practical Concepts Incorporated
                    for the United States Agency for International Development (USAID) in 1969. Leon Rosenberg
                    and Lawrence Posner created it to address the challenge of vague project objectives and
                    unclear causal links."),
            tags$li(tags$strong("1970s — NORAD & GTZ:"), " Adopted and adapted by European bilateral agencies.
                    The German Agency for Technical Cooperation (GTZ, now GIZ) developed the ZOPP
                    (Objectives-Oriented Project Planning) variant."),
            tags$li(tags$strong("1990s — DFID & EU:"), " The UK Department for International Development (DFID,
                    now FCDO) made LogFrames mandatory for all projects. The European Commission adopted it
                    as the standard Project Cycle Management tool."),
            tags$li(tags$strong("2000s — World Bank & UN:"), " The World Bank integrated Results Frameworks
                    (derived from LogFrames) into all operations. UN agencies adopted similar results-based
                    management approaches."),
            tags$li(tags$strong("Present:"), " The LogFrame remains one of the most widely used planning and
                    M&E tools globally, required by nearly all major development funders and implementing organizations.")
          )
      ),

      div(class = "about-section",
          h3("LogFrame vs. Theory of Change"),
          p("While both tools map causal pathways, they serve different purposes:"),
          tags$table(class = "smart-table",
                     tags$thead(
                       tags$tr(
                         tags$th("Aspect"),
                         tags$th("Logical Framework"),
                         tags$th("Theory of Change")
                       )
                     ),
                     tags$tbody(
                       tags$tr(
                         tags$td("Format"),
                         tags$td("Structured 4x4 matrix"),
                         tags$td("Narrative and visual diagram (flexible)")
                       ),
                       tags$tr(
                         tags$td("Focus"),
                         tags$td("Project-level management and monitoring"),
                         tags$td("Understanding the broader change process")
                       ),
                       tags$tr(
                         tags$td("Causal Logic"),
                         tags$td("Linear, hierarchical (if-then)"),
                         tags$td("Can include non-linear, complex pathways")
                       ),
                       tags$tr(
                         tags$td("Assumptions"),
                         tags$td("Listed as a column; often underspecified"),
                         tags$td("Central to the analysis; explored in depth")
                       ),
                       tags$tr(
                         tags$td("Flexibility"),
                         tags$td("Relatively rigid; best for well-defined projects"),
                         tags$td("Highly flexible; suits complex, adaptive programs")
                       ),
                       tags$tr(
                         tags$td("Common Use"),
                         tags$td("Project proposals, donor reporting, M&E frameworks"),
                         tags$td("Strategy development, program design, learning")
                       )
                     )
          ),
          p(style = "margin-top: 12px; font-style: italic; color: #666;",
            "Best practice: Use a Theory of Change to inform your thinking, ",
            "then translate the relevant causal pathway into a LogFrame for management and reporting.")
      ),

      div(class = "about-section",
          h3("Strengths and Limitations"),
          h4("Strengths"),
          tags$ul(
            tags$li("Provides a clear, concise summary of a complex project on a single page"),
            tags$li("Forces logical thinking about causal relationships between activities, outputs, outcomes, and impact"),
            tags$li("Facilitates communication among stakeholders, donors, and implementers"),
            tags$li("Establishes a basis for monitoring and evaluation through indicators and verification sources"),
            tags$li("Encourages identification of assumptions and risks upfront"),
            tags$li("Widely understood across the development sector — a common language")
          ),
          h4("Limitations"),
          tags$ul(
            tags$li("Can oversimplify complex, non-linear change processes into rigid linear chains"),
            tags$li("May become a 'lock-frame' — discouraging adaptive management during implementation"),
            tags$li("Often completed as a bureaucratic requirement rather than a genuine planning tool"),
            tags$li("Assumptions column is frequently neglected or treated superficially"),
            tags$li("Difficult to capture systemic change, emergent outcomes, or contribution (vs. attribution)"),
            tags$li("Can create perverse incentives to choose easily measurable indicators over meaningful ones"),
            tags$li("Does not adequately address power dynamics, equity, or process quality")
          )
      ),

      div(class = "about-section",
          h3("Designing Good Indicators: SMART Criteria"),
          p("The quality of a LogFrame depends heavily on the quality of its indicators.
            The SMART framework provides a useful checklist for designing effective indicators:"),
          tags$table(class = "smart-table",
                     tags$thead(
                       tags$tr(tags$th("Criterion"), tags$th("Description"), tags$th("Example"))
                     ),
                     tags$tbody(
                       tags$tr(
                         tags$td(tags$strong("S"), "pecific"),
                         tags$td("Clearly defined and unambiguous. Answers: What exactly will be measured? For whom? Where?"),
                         tags$td("'Percentage of children aged 12-23 months in Karamoja sub-region who have received all basic vaccinations'")
                       ),
                       tags$tr(
                         tags$td(tags$strong("M"), "easurable"),
                         tags$td("Quantifiable with available tools and methods. Data can be collected reliably and consistently."),
                         tags$td("Uses DHS/coverage survey methodology with standard denominator and numerator definitions")
                       ),
                       tags$tr(
                         tags$td(tags$strong("A"), "chievable"),
                         tags$td("Realistic given resources, timeframe, and context. The target is ambitious but attainable."),
                         tags$td("Increase from 54% to 80% over 5 years (not from 54% to 99% in 1 year)")
                       ),
                       tags$tr(
                         tags$td(tags$strong("R"), "elevant"),
                         tags$td("Directly measures the objective it is associated with. A valid proxy for the intended change."),
                         tags$td("Full immunization coverage directly relates to the purpose of increased MCH service uptake")
                       ),
                       tags$tr(
                         tags$td(tags$strong("T"), "ime-bound"),
                         tags$td("Specifies when the target should be achieved, with clear milestones."),
                         tags$td("'By December 2028' or 'Within 36 months of project inception'")
                       )
                     )
          ),
          h4("Additional Tips for Good Indicator Design"),
          tags$ul(
            tags$li(tags$strong("Disaggregate:"), " Always plan for disaggregation by sex, age, disability status,
                    geographic area, and other relevant equity dimensions."),
            tags$li(tags$strong("Balance quantitative and qualitative:"), " Numbers alone rarely tell the full story.
                    Include qualitative indicators for complex outcomes (e.g., quality of governance, community empowerment)."),
            tags$li(tags$strong("Limit the number:"), " Select 2-3 key indicators per level. More indicators mean more
                    data collection burden without proportional learning value."),
            tags$li(tags$strong("Use existing data sources:"), " Where possible, align with national statistical systems
                    and existing data collection mechanisms to reduce costs and improve sustainability."),
            tags$li(tags$strong("Include process indicators:"), " Especially for governance and capacity building projects,
                    track not just 'what' changed but 'how' it changed."),
            tags$li(tags$strong("Baseline first:"), " Never set a target without a credible baseline. If the baseline is
                    unknown, the first activity should be to establish it.")
          )
      ),

      div(class = "about-section",
          h3("References"),
          div(class = "reference",
              "AusAID (2005). ", tags$em("AusGuideline: The Logical Framework Approach."),
              " Australian Agency for International Development."),
          div(class = "reference",
              "Coleman, G. (1987). 'Logical framework approach to the monitoring and evaluation of agricultural and rural development projects.'",
              tags$em(" Project Appraisal,"), " 2(4), 251-259."),
          div(class = "reference",
              "DFID (2011). ", tags$em("How To Note: Guidance on using the revised Logical Framework."),
              " Department for International Development, UK."),
          div(class = "reference",
              "European Commission (2004). ",
              tags$em("Aid Delivery Methods: Project Cycle Management Guidelines."),
              " EuropeAid Cooperation Office."),
          div(class = "reference",
              "Gasper, D. (2000). 'Evaluating the Logical Framework Approach — towards learning-oriented development evaluation.'",
              tags$em(" Public Administration and Development,"), " 20(1), 17-28."),
          div(class = "reference",
              "Hummelbrunner, R. (2010). 'Beyond Logframe: Critique, variations and alternatives.'",
              " In N. Fujita (Ed.), ", tags$em("Beyond Logframe,"),
              " Foundation for Advanced Studies on International Development, Tokyo."),
          div(class = "reference",
              "NORAD (1999). ", tags$em("The Logical Framework Approach (LFA): Handbook for Objectives-Oriented Planning."),
              " Norwegian Agency for Development Cooperation."),
          div(class = "reference",
              "Practical Concepts Incorporated (1979). ", tags$em("The Logical Framework: A Manager's Guide to a Scientific Approach to Design and Evaluation."),
              " Prepared for USAID."),
          div(class = "reference",
              "Rogers, P. (2014). ", tags$em("Theory of Change."), " Methodological Briefs — Impact Evaluation No. 2, UNICEF Office of Research."),
          div(class = "reference",
              "World Bank (2012). ", tags$em("Designing a Results Framework for Achieving Results: A How-To Guide."),
              " Independent Evaluation Group, World Bank Group.")
      )
    )
  })

  # ---------- Collect all logframe data into a data frame ----------
  collect_logframe_data <- function() {
    n_outcomes <- input$num_outcomes
    n_outputs <- input$num_outputs
    n_activities <- input$num_activities

    rows <- list()
    rows[[1]] <- data.frame(
      Level = "Goal/Impact",
      Reference = "Goal",
      Narrative_Summary = get_val("goal_narrative"),
      OVIs = get_val("goal_ovi"),
      Means_of_Verification = get_val("goal_mov"),
      Assumptions_Risks = get_val("goal_assumptions"),
      stringsAsFactors = FALSE
    )

    for (oc in 1:n_outcomes) {
      rows[[length(rows) + 1]] <- data.frame(
        Level = "Purpose/Outcome",
        Reference = paste("Outcome", oc),
        Narrative_Summary = get_val(paste0("purpose_", oc, "_narrative")),
        OVIs = get_val(paste0("purpose_", oc, "_ovi")),
        Means_of_Verification = get_val(paste0("purpose_", oc, "_mov")),
        Assumptions_Risks = get_val(paste0("purpose_", oc, "_assumptions")),
        stringsAsFactors = FALSE
      )
      for (op in 1:n_outputs) {
        pfx <- paste0("output_", oc, "_", op, "_")
        rows[[length(rows) + 1]] <- data.frame(
          Level = "Output",
          Reference = paste0("Output ", oc, ".", op),
          Narrative_Summary = get_val(paste0(pfx, "narrative")),
          OVIs = get_val(paste0(pfx, "ovi")),
          Means_of_Verification = get_val(paste0(pfx, "mov")),
          Assumptions_Risks = get_val(paste0(pfx, "assumptions")),
          stringsAsFactors = FALSE
        )
        for (ac in 1:n_activities) {
          apfx <- paste0("activity_", oc, "_", op, "_", ac, "_")
          rows[[length(rows) + 1]] <- data.frame(
            Level = "Activity",
            Reference = paste0("Activity ", oc, ".", op, ".", ac),
            Narrative_Summary = get_val(paste0(apfx, "narrative")),
            OVIs = get_val(paste0(apfx, "ovi")),
            Means_of_Verification = get_val(paste0(apfx, "mov")),
            Assumptions_Risks = get_val(paste0(apfx, "assumptions")),
            stringsAsFactors = FALSE
          )
        }
      }
    }
    bind_rows(rows)
  }

  # ---------- CSV Download ----------
  output$download_csv <- downloadHandler(
    filename = function() {
      paste0(gsub(" ", "_", input$project_name), "_LogFrame_", Sys.Date(), ".csv")
    },
    content = function(file) {
      df <- collect_logframe_data()
      write.csv(df, file, row.names = FALSE)
    }
  )

  # ---------- HTML Report Download ----------
  output$download_html <- downloadHandler(
    filename = function() {
      paste0(gsub(" ", "_", input$project_name), "_LogFrame_Report_", Sys.Date(), ".html")
    },
    content = function(file) {
      theme <- current_theme()
      df <- collect_logframe_data()
      project <- input$project_name

      # Build HTML table rows
      table_rows <- ""
      for (i in seq_len(nrow(df))) {
        row <- df[i, ]
        bg <- switch(row$Level,
                     "Goal/Impact" = theme$goal_color,
                     "Purpose/Outcome" = theme$purpose_color,
                     "Output" = theme$output_color,
                     "Activity" = theme$activity_color,
                     "#666")
        table_rows <- paste0(table_rows, sprintf('
          <tr>
            <td style="background-color:%s; color:white; font-weight:bold; text-align:center;
                        white-space:nowrap; padding:10px 8px; font-size:11px;">%s</td>
            <td style="padding:10px 12px; border:1px solid #ddd;">%s</td>
            <td style="padding:10px 12px; border:1px solid #ddd;">%s</td>
            <td style="padding:10px 12px; border:1px solid #ddd;">%s</td>
            <td style="padding:10px 12px; border:1px solid #ddd;">%s</td>
          </tr>',
          bg, htmltools::htmlEscape(row$Reference),
          htmltools::htmlEscape(row$Narrative_Summary),
          htmltools::htmlEscape(row$OVIs),
          htmltools::htmlEscape(row$Means_of_Verification),
          htmltools::htmlEscape(row$Assumptions_Risks)
        ))
      }

      html_content <- sprintf('<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>%s — Logical Framework Report</title>
  <style>
    body {
      font-family: "Segoe UI", Roboto, Arial, sans-serif;
      margin: 40px;
      color: #333;
      line-height: 1.6;
    }
    h1 {
      color: %s;
      border-bottom: 3px solid %s;
      padding-bottom: 10px;
    }
    .meta {
      color: #888;
      margin-bottom: 30px;
      font-size: 14px;
    }
    table {
      width: 100%%;
      border-collapse: collapse;
      margin-top: 20px;
      font-size: 13px;
    }
    th {
      background-color: %s;
      color: %s;
      padding: 12px 14px;
      text-align: left;
      font-size: 12px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    td {
      vertical-align: top;
      line-height: 1.5;
    }
    .footer {
      margin-top: 40px;
      padding-top: 15px;
      border-top: 1px solid #ddd;
      font-size: 12px;
      color: #999;
    }
  </style>
</head>
<body>
  <h1>%s</h1>
  <div class="meta">Logical Framework Report — Generated on %s<br>
  Tool: LogFrame Builder — Impact Mojo</div>
  <table>
    <thead>
      <tr>
        <th style="width:100px;">Level</th>
        <th>Narrative Summary</th>
        <th>Objectively Verifiable Indicators</th>
        <th>Means of Verification</th>
        <th>Assumptions / Risks</th>
      </tr>
    </thead>
    <tbody>
      %s
    </tbody>
  </table>
  <div class="footer">
    This document was generated using the LogFrame Builder — Impact Mojo application.
    The Logical Framework Approach is a planning and management tool widely used across the
    international development sector.
  </div>
</body>
</html>',
        htmltools::htmlEscape(project),
        theme$primary, theme$secondary,
        theme$primary, theme$header_text,
        htmltools::htmlEscape(project),
        Sys.Date(),
        table_rows
      )

      writeLines(html_content, file)
    }
  )
}


# =============================================================================
# RUN
# =============================================================================

shinyApp(ui = ui, server = server)
