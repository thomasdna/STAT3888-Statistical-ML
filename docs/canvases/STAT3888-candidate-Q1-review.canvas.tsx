import {
  BarChart,
  Callout,
  Card,
  CardBody,
  CardHeader,
  Divider,
  Grid,
  H1,
  H2,
  H3,
  Pill,
  Row,
  Spacer,
  Stack,
  Stat,
  Table,
  Text,
  useHostTheme,
} from "cursor/canvas";

const SRC = "Source: ABS Australian Health Survey 2011-13, National Health Survey Basic CURF, adults 18+, survey-weighted";

function Label({ children }: { children: string }) {
  const theme = useHostTheme();
  return (
    <Text
      size="small"
      weight="semibold"
      style={{
        color: theme.text.tertiary,
        letterSpacing: "0.08em",
        textTransform: "uppercase",
      }}
    >
      {children}
    </Text>
  );
}

function Caption({ children }: { children: string }) {
  const theme = useHostTheme();
  return (
    <Text size="small" style={{ color: theme.text.quaternary }}>
      {children}
    </Text>
  );
}

function Header() {
  const theme = useHostTheme();
  return (
    <Stack gap={12}>
      <Row gap={8} align="center" wrap>
        <Pill size="sm" active>
          Candidate Q1 review
        </Pill>
        <Pill size="sm">National Health Survey</Pill>
        <Pill size="sm">n = 5,761 biomedical adults</Pill>
        <Spacer />
        <Caption>Scripts 10-12, run on our own data</Caption>
      </Row>
      <H1>The proposal is executable, but RQ1 has a one-sentence negative answer</H1>
      <Text style={{ maxWidth: 900, color: theme.text.secondary }}>
        Every variable named in the document exists and links correctly, and the
        motivating "89% unaware" statistic reproduces to within a percentage
        point. The problem is what happens next: no combination of routinely
        available non-laboratory information predicts high total cholesterol any
        better than age and sex alone, and none of it beats the age-45 testing
        rule Australia already uses. RQ2 — who a screening rule misses — is the
        half worth keeping, and it has genuinely interesting answers.
      </Text>
    </Stack>
  );
}

function Headline() {
  return (
    <Row gap={28} wrap>
      <Stat value="0.581 to 0.576" label="Out-of-sample AUC, age+sex to all predictors" tone="danger" />
      <Divider style={{ width: 1, alignSelf: "stretch" }} />
      <Stat value="-0.2 pp" label="Cases found vs the age-45 rule" tone="danger" />
      <Divider style={{ width: 1, alignSelf: "stretch" }} />
      <Stat value="+25.8 pp" label="Same comparison, but for low HDL" tone="success" />
      <Divider style={{ width: 1, alignSelf: "stretch" }} />
      <Stat value="0.521" label="Model AUC in the most disadvantaged areas" tone="warning" />
    </Row>
  );
}

function OutcomeProblem() {
  const theme = useHostTheme();
  return (
    <Stack gap={14}>
      <Stack gap={4}>
        <Label>The outcome definition</Label>
        <H2>"89% did not report a diagnosis" is real, and does not mean unaware</H2>
      </Stack>
      <Text style={{ maxWidth: 900, color: theme.text.secondary }}>
        We reproduce the figure exactly: of adults with measured total
        cholesterol at or above 5.5 mmol/L, 88.3% have no current self-report.
        But the number is built from two variables that answer different
        questions, and three separate things inflate it.
      </Text>

      <Grid columns={3} gap={16}>
        <Card>
          <CardHeader>Past diagnoses count as unaware</CardHeader>
          <CardBody>
            <Stack gap={8}>
              <Text size="small">
                Of 2,368 adults with a high-cholesterol condition record, 788
                report it as "ever told, not current". They know. The strict
                definition still counts them as unrecognised.
              </Text>
              <Caption>CONDSTAT code 3, conditions file</Caption>
            </Stack>
          </CardBody>
        </Card>
        <Card>
          <CardHeader>Treatment makes levels look normal</CardHeader>
          <CardBody>
            <Stack gap={8}>
              <Text size="small">
                Among adults who do report current high cholesterol, only 34.2%
                measure high — because 75.5% of those whose medication status is
                known are on lipid-lowering medication, and it is working.
              </Text>
              <Caption>CVDMEDST codes 1-2, n = 572 with known status</Caption>
            </Stack>
          </CardBody>
        </Card>
        <Card>
          <CardHeader>A threshold is not a diagnosis</CardHeader>
          <CardBody>
            <Stack gap={8}>
              <Text size="small">
                Australian guidelines treat on absolute cardiovascular risk, not
                on total cholesterol alone. Many of the 88% would not be
                recommended treatment, so "undiagnosed" overstates the gap.
              </Text>
              <Caption>Definitional, not a data issue</Caption>
            </Stack>
          </CardBody>
        </Card>
      </Grid>

      <Callout tone="warning" title="The medication-aware alternative has the opposite problem">
        <Text size="small">
          CVDMEDST code 3 ("not using lipid medication and has abnormal
          results") is the right shape for a screening target and needs no
          self-report. But 52.0% of fasted adults meet it, because the ABS
          definition counts any abnormal lipid. A condition affecting half the
          population cannot be triaged — you would just test everyone. It also
          costs 23% of the sample, since CVDMEDST is defined only for the 4,353
          respondents who fasted 8+ hours.
        </Text>
      </Callout>
    </Stack>
  );
}

function BmiWaistSection() {
  const theme = useHostTheme();
  return (
    <Stack gap={14}>
      <Stack gap={4}>
        <Label>Assigned task: BMI and obesity as screening indicators</Label>
        <H2>Which lipid you pick decides whether adiposity is useful at all</H2>
      </Stack>
      <Text style={{ maxWidth: 900, color: theme.text.secondary }}>
        BMI discriminates low HDL reasonably well and is close to useless for
        total and LDL cholesterol. Age is the better single marker for total
        cholesterol, and is worthless for HDL. This is the same split our NNPAS
        analysis found on a different survey.
      </Text>

      <Card>
        <CardHeader>Weighted AUC of single markers, by lipid outcome</CardHeader>
        <CardBody>
          <Stack gap={10}>
            <BarChart
              categories={[
                "High total cholesterol",
                "Low HDL (sex-specific)",
                "High LDL (fasting)",
                "Untreated dyslipidaemia",
              ]}
              series={[
                { name: "BMI", data: [0.572, 0.657, 0.575, 0.593], tone: "info" },
                { name: "Waist circumference", data: [0.565, 0.621, 0.574, 0.573], tone: "success" },
                { name: "Age", data: [0.605, 0.493, 0.568, 0.498], tone: "warning" },
              ]}
              height={260}
              beginAtZero={false}
              yMin={0.45}
              yMax={0.7}
              showValues
              referenceLines={[{ value: 0.5, label: "No discrimination", tone: "danger" }]}
            />
            <Caption>
              {"Weighted AUC (0.5 = no discrimination). " + SRC + ". n = 4,123-5,683 depending on outcome."}
            </Caption>
          </Stack>
        </CardBody>
      </Card>

      <Grid columns={2} gap={16}>
        <Card>
          <CardHeader>Prevalence of high total cholesterol</CardHeader>
          <CardBody>
            <Stack gap={10}>
              <Table
                headers={["Category", "BMI", "Waist"]}
                columnAlign={["left", "right", "right"]}
                rows={[
                  ["Lowest category", "13.6%", "27.3%"],
                  ["Normal / not at risk", "28.4%", "27.3%"],
                  ["Overweight / increased", "38.1%", "40.1%"],
                  ["Obese I / substantially inc.", "37.2%", "37.5%"],
                  ["Obese II-III", "39.5%", "-"],
                ]}
              />
              <Caption>
                The gradient flattens above "overweight" and is non-monotonic for
                waist. BMI beats waist on every outcome tested.
              </Caption>
            </Stack>
          </CardBody>
        </Card>
        <Card>
          <CardHeader>Does the association differ by age or sex?</CardHeader>
          <CardBody>
            <Stack gap={10}>
              <Table
                headers={["Interaction", "p-value", "Verdict"]}
                columnAlign={["left", "right", "left"]}
                rowTone={[undefined, "danger"]}
                rows={[
                  ["BMI x sex", "0.31", "No difference"],
                  ["BMI x age", "4 x 10⁻⁹", "Strong difference"],
                ]}
              />
              <Text size="small">
                Stratified, the odds ratio per 5 kg/m² is 1.46 at ages 18-34 but
                0.80-0.91 at 55+. The association <b>reverses</b> with age,
                because treatment is concentrated in heavier older adults.
              </Text>
              <Caption>Age- and sex-adjusted survey-weighted logistic regression</Caption>
            </Stack>
          </CardBody>
        </Card>
      </Grid>

      <Callout tone="info" title="Adjusted odds ratios make the same point">
        <Text size="small">
          Per 5 kg/m² of BMI, age- and sex-adjusted: low HDL 1.73 (1.57-1.91),
          untreated dyslipidaemia 1.37 (1.27-1.47), high LDL 1.17 (1.09-1.25),
          high total cholesterol 1.13 (1.07-1.21). Adiposity is an HDL story.
        </Text>
      </Callout>
    </Stack>
  );
}

function Rq1Section() {
  const theme = useHostTheme();
  return (
    <Stack gap={14}>
      <Stack gap={4}>
        <Label>RQ1 — how accurately?</Label>
        <H2>Adding every available predictor to age and sex changes nothing</H2>
      </Stack>
      <Text style={{ maxWidth: 900, color: theme.text.secondary }}>
        Nested elastic-net logistic models, 5 x 10-fold cross-validation,
        evaluated out-of-sample with weighted AUC. Predictor blocks follow the
        proposal's own table, added in the order a clinic would collect them.
      </Text>

      <Card>
        <CardHeader>Out-of-sample AUC by model and outcome</CardHeader>
        <CardBody>
          <Stack gap={10}>
            <Table
              headers={[
                "Outcome",
                "Age + sex",
                "+ BMI, waist",
                "+ BP",
                "+ smoking, PA",
                "+ income, SES",
                "Gain",
              ]}
              columnAlign={["left", "right", "right", "right", "right", "right", "right"]}
              rowTone={["neutral", "danger", "success", "success"]}
              rows={[
                ["High total cholesterol", "0.597", "0.598", "0.599", "0.597", "0.592", "-0.005"],
                ["High + not self-reported (their RQ1)", "0.581", "0.582", "0.583", "0.580", "0.576", "-0.005"],
                ["Untreated dyslipidaemia", "0.478", "0.588", "0.590", "0.583", "0.588", "+0.110"],
                ["Low HDL", "0.564", "0.693", "0.699", "0.702", "0.708", "+0.144"],
              ]}
            />
            <Caption>
              {"Weighted AUC, mean of 5 cross-validation replicates (replicate SD <= 0.002). " + SRC}
            </Caption>
          </Stack>
        </CardBody>
      </Card>

      <Card>
        <CardHeader>The decisive test: can a model beat "test everyone aged 45+"?</CardHeader>
        <CardBody>
          <Stack gap={10}>
            <BarChart
              categories={[
                "High total cholesterol",
                "High + not self-reported",
                "Untreated dyslipidaemia",
                "Low HDL",
              ]}
              series={[
                { name: "Test everyone aged 45+", data: [60.4, 58.8, 50.5, 46.5], tone: "warning" },
                { name: "Full non-laboratory model", data: [59.3, 58.6, 57.1, 72.3], tone: "info" },
              ]}
              height={250}
              valueSuffix="%"
              showValues
            />
            <Caption>
              {"Share of all cases detected, with each policy sized to test the same ~50% of the population. " + SRC}
            </Caption>
          </Stack>
        </CardBody>
      </Card>

      <Callout tone="danger" title="Answer to RQ1 as written">
        <Text size="small">
          Not accurately, and no better than asking someone's age. For the
          proposal's own outcome the full model detects 58.6% of cases against
          58.8% for the age rule. The screening question only becomes worth
          asking if the outcome moves to HDL or untreated dyslipidaemia.
        </Text>
      </Callout>
    </Stack>
  );
}

function Rq2Section() {
  const theme = useHostTheme();
  return (
    <Stack gap={14}>
      <Stack gap={4}>
        <Label>RQ2 — who gets missed?</Label>
        <H2>This is the stronger half of the proposal</H2>
      </Stack>
      <Text style={{ maxWidth: 900, color: theme.text.secondary }}>
        Because the model is driven almost entirely by age, a fixed risk
        threshold behaves like an age cut-off wearing a disguise — and it
        performs worst for the group a screening programme would most want to
        reach.
      </Text>

      <Grid columns={2} gap={16}>
        <Card>
          <CardHeader>Share flagged at a fixed threshold, by age</CardHeader>
          <CardBody>
            <Stack gap={10}>
              <BarChart
                categories={["18-34", "35-44", "45-54", "55-64", "65+"]}
                series={[{ name: "Share flagged for testing", data: [1.1, 12.3, 50.4, 80.2, 97.5], tone: "info" }]}
                height={220}
                valueSuffix="%"
                showValues
              />
              <Caption>
                Flagging the highest-risk 40% of adults overall. Age group, share
                flagged (%).
              </Caption>
            </Stack>
          </CardBody>
        </Card>
        <Card>
          <CardHeader>Within-subgroup AUC</CardHeader>
          <CardBody>
            <Stack gap={10}>
              <BarChart
                categories={["18-34", "35-44", "45-54", "55-64", "65+", "SEIFA Q1", "SEIFA Q5"]}
                series={[{ name: "Within-group weighted AUC", data: [0.601, 0.539, 0.507, 0.458, 0.468, 0.521, 0.618], tone: "warning" }]}
                height={220}
                beginAtZero={false}
                yMin={0.4}
                yMax={0.65}
                showValues
                referenceLines={[{ value: 0.5, label: "Random", tone: "danger" }]}
              />
              <Caption>
                Subgroup, weighted AUC for measured high total cholesterol. Below
                0.5 in both bands over 55.
              </Caption>
            </Stack>
          </CardBody>
        </Card>
      </Grid>

      <Card>
        <CardHeader>Who has had no cholesterol test in five years (adults 45+)</CardHeader>
        <CardBody>
          <Stack gap={10}>
            <Table
              headers={["Predictor", "Odds ratio", "95% CI", "p"]}
              columnAlign={["left", "right", "right", "right"]}
              rowTone={[undefined, "success", "warning"]}
              rows={[
                ["Age (per year)", "0.969", "0.941-0.997", "0.032"],
                ["BMI (per kg/m²)", "0.927", "0.886-0.971", "0.002"],
                ["SEIFA decile (per decile)", "0.900", "0.829-0.976", "0.012"],
                ["Current smoker vs never", "1.667", "0.910-3.052", "0.096"],
              ]}
            />
            <Caption>
              {"Survey-weighted logistic regression, outcome = untested in 5 years. n = 3,720; 8.9% untested. CHOL5YR is only asked universally from age 45."}
            </Caption>
          </Stack>
        </CardBody>
      </Card>

      <Callout tone="success" title="The finding that explains everything else">
        <Text size="small">
          Higher BMI predicts being <b>more</b> likely to have already been
          tested — 32% lower odds of going untested per 5 kg/m². Clinicians
          already use body size to decide who gets a lipid panel, which is
          exactly why BMI has no headroom left as a screening variable. The
          people BMI would flag are the people already being tested.
          Disadvantage runs the other way: the most disadvantaged areas are the
          least tested and the least well modelled.
        </Text>
      </Callout>
    </Stack>
  );
}

function DataNotes() {
  return (
    <Stack gap={14}>
      <Stack gap={4}>
        <Label>For Stacy and Gordon</Label>
        <H2>Data-structure findings that change the task list</H2>
      </Stack>
      <Card>
        <CardBody>
          <Table
            headers={["Issue", "What we found", "Action"]}
            columnAlign={["left", "left", "left"]}
            rowTone={["danger", "danger", "warning", "success", "warning", "info"]}
            rows={[
              [
                "Person key",
                "ABSPID is not unique in the NHS — it runs 1-6, the person number within household. The key is ABSLID + ABSPID.",
                "Any merge on ABSPID alone silently explodes to 139 million rows.",
              ],
              [
                "Self-reported high cholesterol",
                "There is no person-level flag in the NHS. It must come from the conditions file: EVERCURF = 14693 with CONDSTAT for currency. 2,368 adults have a record.",
                "Answers Stacy's open task. HCHOLBC only exists in the nutrition survey.",
              ],
              [
                "CVDMEDST is fasting-only",
                "All 4,353 valid records are FASTSTAD = 1; all 1,358 non-fasting participants are 'not applicable'.",
                "Budget for losing 23% of the sample if you use it.",
              ],
              [
                "Testing history exists",
                "CHOL5YR and CHOLEST record whether and when cholesterol was last checked. Not in the proposal.",
                "The only variables that speak directly to 'prioritising people for testing'.",
              ],
              [
                "CHOL5YR is age-gated",
                "Asked universally only from age 45; 85-97% 'not applicable' below that. n = 3,954 in the biomedical sample.",
                "Any testing-history analysis is a 45+ analysis. Say so up front.",
              ],
              [
                "Sample size",
                "Our funnel gives 5,761 adults 18+ and 5,683 with measured cholesterol. The predictor table quotes 5,443.",
                "Missing-data percentages match closely, so reconcile the filter with Gordon.",
              ],
            ]}
          />
        </CardBody>
      </Card>
      <Callout tone="warning" title="The HDL/LDL ratio asked for in the chat cannot be computed">
        <Text size="small">
          HDLCHREB and LDLRESB are released only as ordered bands (for example
          "1.0 to less than 1.3"), so any ratio would compound two layers of
          banding error. Use the status variables HDLCHSEX and LDLNTR instead,
          which is what the analysis above does.
        </Text>
      </Callout>
    </Stack>
  );
}

function Recommendation() {
  return (
    <Stack gap={14}>
      <Stack gap={4}>
        <Label>Recommendation</Label>
        <H2>Three ways to keep the question, in order of strength</H2>
      </Stack>
      <Grid columns={3} gap={16}>
        <Card>
          <CardHeader>1. Move the outcome to HDL</CardHeader>
          <CardBody>
            <Stack gap={8}>
              <Text size="small">
                This is where non-laboratory information genuinely works: AUC
                0.708, and 72.3% of cases found against 46.5% for the age rule.
                It also answers the chat's HDL-versus-LDL question directly.
              </Text>
              <Pill size="sm" active>
                Strongest evidence
              </Pill>
            </Stack>
          </CardBody>
        </Card>
        <Card>
          <CardHeader>2. Promote RQ2 to primary</CardHeader>
          <CardBody>
            <Stack gap={8}>
              <Text size="small">
                "Which groups does a non-laboratory screening rule
                systematically miss?" is a novel framing with clean answers, and
                the age and SEIFA results are strong enough to carry a report.
              </Text>
              <Pill size="sm">Most novel</Pill>
            </Stack>
          </CardBody>
        </Card>
        <Card>
          <CardHeader>3. Model testing, not lipids</CardHeader>
          <CardBody>
            <Stack gap={8}>
              <Text size="small">
                CHOL5YR makes "who goes untested" directly answerable, and it is
                closer to the stated purpose than modelling cholesterol levels.
                Restricted to 45+.
              </Text>
              <Pill size="sm">Closest to the stated purpose</Pill>
            </Stack>
          </CardBody>
        </Card>
      </Grid>

      <Callout tone="neutral" title="Two things to hold the line on">
        <Stack gap={6}>
          <Text size="small">
            <b>Keep the framing associational.</b> Nothing here supports the
            chat's causal language about "which factor may be causing the high
            cholesterol". This is one cross-sectional survey, and the treatment
            effects above show the arrow can point backwards: being heavier
            causes more testing, which causes lower measured cholesterol.
          </Text>
          <Text size="small">
            <b>The two candidates do not share a sample.</b> The cholesterol
            work uses the National Health Survey; our BMI and cardiometabolic
            work uses the nutrition survey, which has no smoking, exercise-level
            or testing items. The NHS has no dietary data at all. Nothing pools.
          </Text>
        </Stack>
      </Callout>
    </Stack>
  );
}

function CrossCheck() {
  const theme = useHostTheme();
  return (
    <Card>
      <CardHeader>Cross-check against our existing NNPAS analysis</CardHeader>
      <CardBody>
        <Stack gap={10}>
          <Text size="small" style={{ color: theme.text.secondary }}>
            The two surveys agree, which is the most reassuring result here.
            Script 06 found that blood pressure, dysglycaemia and low HDL track
            BMI while total cholesterol barely does; scripts 11-12 reproduce that
            split on a different sample with different variables. Script 08 found
            that socioeconomic and behavioural blocks add roughly 13% of what BMI
            alone adds to cardiometabolic prediction; here they add nothing at
            all to a cholesterol outcome. Both point at the same conclusion: BMI
            carries metabolic information, and almost none of it is about total
            cholesterol.
          </Text>
          <Divider />
          <Row gap={28} wrap>
            <Stat value="2 surveys" label="Independent samples, same conclusion" />
            <Stat value="5,761 + 4,444" label="NHS and NNPAS biomedical adults" />
            <Stat value="12 figures" label="Generated in outputs/figures" />
          </Row>
        </Stack>
      </CardBody>
    </Card>
  );
}

export default function CandidateQ1Review() {
  return (
    <Stack gap={34} style={{ padding: 28, maxWidth: 1180 }}>
      <Header />
      <Headline />
      <Divider />
      <OutcomeProblem />
      <Divider />
      <BmiWaistSection />
      <Divider />
      <Rq1Section />
      <Divider />
      <Rq2Section />
      <Divider />
      <DataNotes />
      <Divider />
      <Recommendation />
      <CrossCheck />
      <Caption>
        {"All estimates from scripts 10-12 in the STAT3888 repository. " + SRC + ". Weights: NHMSPERW with 60 jackknife replicates (RPWGT01-60)."}
      </Caption>
    </Stack>
  );
}
