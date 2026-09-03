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
    <Stack gap={10}>
      <Row gap={8} align="center" wrap>
        <Pill size="sm" tone="info" active>
          Feasibility check
        </Pill>
        <Pill size="sm">NNPAS biomedical, adults 18+</Pill>
        <Spacer />
        <Text size="small" style={{ color: theme.text.quaternary }}>
          For the 8PM question review
        </Text>
      </Row>
      <H1>Can we identify undetected high cholesterol without a blood test?</H1>
      <Text style={{ maxWidth: 880, color: theme.text.secondary }}>
        The proposed direction is feasible and worth pursuing, but the outcome
        definition in the current wording will not work, and one of the suggested
        additions cannot be computed from this dataset at all. Both have clean
        fixes. Everything below is measured on our own data, not assumed.
      </Text>
    </Stack>
  );
}

/* ------------------------------------------------------ self-report problem */

function SelfReport() {
  const theme = useHostTheme();
  return (
    <Stack gap={12}>
      <Label>Finding 1 — blocking</Label>
      <H2>Self-reported high cholesterol cannot define the outcome</H2>

      <Grid columns={4} gap={12}>
        <Stat value="88.3%" label="Of adults measuring high, do not report it" tone="danger" />
        <Stat value="66.7%" label="Of those reporting it, measure normal" tone="danger" />
        <Stat value="98" label="Of 1,612 untreated cases self-report it" tone="danger" />
        <Stat value="1,131" label="Raw 'measured high, not reported' cell" />
      </Grid>

      <Text style={{ maxWidth: 900, color: theme.text.secondary }}>
        The question needs a marker of who is unaware. `HCHOLBC` is the only
        self-report item available, and it fails in both directions at once —
        almost nobody with a high reading reports it, while two thirds of those
        who do report it now measure normal because they are on treatment. A
        model fitted to that outcome would largely be predicting{" "}
        <Text weight="semibold">who has seen a doctor</Text>, not who has
        undetected high cholesterol.
      </Text>

      <H3>Self-report against ABS's medication-aware classification</H3>
      <Table
        headers={["Actual lipid status", "Does not report high cholesterol", "Reports it", "% reporting"]}
        rows={[
          ["Untreated dyslipidaemia", "1,514", "98", "6.1%"],
          ["Treated, still abnormal", "152", "131", "46.3%"],
          ["Treated, controlled", "132", "142", "51.8%"],
          ["No dyslipidaemia", "959", "6", "0.6%"],
        ].map(([a, b, c, dd], i) => [
          <Text size="small" weight={i === 0 ? "semibold" : "normal"}>{a}</Text>,
          <Text size="small" style={{ fontFamily: "monospace" }}>{b}</Text>,
          <Text size="small" style={{ fontFamily: "monospace" }}>{c}</Text>,
          <Text size="small" style={{ fontFamily: "monospace", color: theme.text.secondary }}>{dd}</Text>,
        ])}
        columnAlign={["left", "right", "right", "right"]}
        rowTone={["danger", undefined, undefined, undefined]}
      />
      <Caption>
        Source: ABS NNPAS 2011-12 Basic CURF, biomedical adults 18+. Rows are
        CVDMEDST categories; columns are HCHOLBC.
      </Caption>

      <Callout tone="success" title="The fix: CVDMEDST, which ABS built for exactly this">
        <Text size="small">
          `CVDMEDST` is "Dyslipidaemia status (lipid medication status and lipid
          levels)". It separates treated-and-controlled from
          treated-but-abnormal from{" "}
          <Text weight="semibold">not on medication with abnormal results</Text>{" "}
          — which is precisely the group the question is about, and which
          self-report cannot isolate. It gives a clean screening contrast of{" "}
          <Text weight="semibold">1,612 untreated cases against 965 with no
          dyslipidaemia</Text>. The cost is that it requires a fasting sample, so
          the analysable n with a measured BMI is 2,471 rather than ~3,540.
        </Text>
      </Callout>
    </Stack>
  );
}

/* --------------------------------------------------------- the BMI question */

function Anthropometry() {
  const theme = useHostTheme();

  const rows: Array<[string, string, string, string, string, string, "success" | "danger" | undefined]> = [
    ["High total cholesterol (≥5.5)", "3,586", "36.9%", "0.522", "0.515", "0.577", "danger"],
    ["High LDL (≥3.5, fasting)", "2,999", "36.1%", "0.539", "0.540", "0.565", "danger"],
    ["Low HDL (<1.0 M / <1.3 F)", "3,586", "22.5%", "0.646", "0.624", "0.493", "success"],
    ["Untreated dyslipidaemia", "2,471", "62.7%", "0.634", "0.636", "0.643", "success"],
  ];

  return (
    <Stack gap={12}>
      <Label>Finding 2 — reframes my assigned task</Label>
      <H2>Anthropometry is useless for cholesterol but works for HDL</H2>

      <Text style={{ maxWidth: 900, color: theme.text.secondary }}>
        My task as allocated was to test whether BMI or waist can help identify
        high cholesterol. The answer is no, decisively — and that is not a dead
        end, because the picture flips completely for HDL.
      </Text>

      <Table
        headers={["Lipid outcome", "n", "Prevalence", "AUC BMI", "AUC waist", "AUC age"]}
        rows={rows.map(([a, b, c, d, e, f]) => [
          <Text size="small" weight="semibold">{a}</Text>,
          <Text size="small" style={{ color: theme.text.tertiary }}>{b}</Text>,
          <Text size="small" style={{ fontFamily: "monospace" }}>{c}</Text>,
          <Text size="small" style={{ fontFamily: "monospace" }}>{d}</Text>,
          <Text size="small" style={{ fontFamily: "monospace" }}>{e}</Text>,
          <Text size="small" style={{ fontFamily: "monospace" }}>{f}</Text>,
        ])}
        columnAlign={["left", "right", "right", "right", "right", "right"]}
        rowTone={rows.map((r) => r[6])}
      />
      <Caption>
        AUC of each single predictor for each outcome. 0.5 means no
        discrimination. Red rows: anthropometry is at chance. Green rows:
        anthropometry carries real signal.
      </Caption>

      <BarChart
        categories={["Total cholesterol", "LDL", "Low HDL", "Untreated dyslipidaemia"]}
        series={[
          { name: "BMI", data: [0.522, 0.539, 0.646, 0.634], tone: "info" },
          { name: "Waist", data: [0.515, 0.54, 0.624, 0.636], tone: "neutral" },
          { name: "Age", data: [0.577, 0.565, 0.493, 0.643], tone: "warning" },
        ]}
        height={280}
      />
      <Caption>
        Y axis: AUC for the outcome. X axis: lipid outcome. Adiposity and age are
        near-complementary — BMI discriminates HDL (0.646) where age does not
        (0.493), and age discriminates cholesterol (0.577) better than BMI does
        (0.522).
      </Caption>

      <Grid columns={2} gap={16} align="start">
        <Card>
          <CardHeader>The gradient is not even monotonic</CardHeader>
          <CardBody>
            <Text size="small" style={{ color: theme.text.secondary }}>
              Prevalence of high total cholesterol by BMI category: 32.9% at
              normal weight, 39.6% at overweight, then{" "}
              <Text weight="semibold">back down to 35.7% at obese</Text>. There
              is no usable dose-response to exploit for screening.
            </Text>
          </CardBody>
        </Card>
        <Card>
          <CardHeader>Consistent with our existing RQ1 result</CardHeader>
          <CardBody>
            <Text size="small" style={{ color: theme.text.secondary }}>
              In the cardiometabolic work already completed, total cholesterol was
              the one risk factor of five that did not track BMI. This is the same
              phenomenon measured directly, so the two analyses corroborate each
              other.
            </Text>
          </CardBody>
        </Card>
      </Grid>

      <Callout tone="info" title="Suggested reframe of my contribution">
        <Text size="small">
          Rather than "can BMI identify high cholesterol" (answer: no, stop),
          ask <Text weight="semibold">which lipid abnormalities can be triaged
          from non-laboratory information and which genuinely require a blood
          test</Text>. That has an actionable answer, it uses the null result
          rather than being defeated by it, and it is a direct argument for why
          the team's question matters.
        </Text>
      </Callout>
    </Stack>
  );
}

/* ------------------------------------------------------- the ratio problem */

function RatioProblem() {
  const theme = useHostTheme();
  return (
    <Stack gap={12}>
      <Label>Finding 3 — blocks one suggestion</Label>
      <H2>An HDL-to-LDL ratio cannot be computed from this dataset</H2>

      <Grid columns="3fr 2fr" gap={16} align="start">
        <Stack gap={10}>
          <Text style={{ color: theme.text.secondary }}>
            Every lipid in the Basic CURF is supplied as an{" "}
            <Text weight="semibold">ordered band, never a number</Text>.
            `CHOLRESB` runs "Less than 4.0", "4.0 to less than 4.5", … up to{" "}
            <Text weight="semibold">"7.0 or more"</Text>. A ratio of two banded
            variables requires assigning each band a midpoint, and the top
            category is open-ended so it has no midpoint at all. We already ruled
            band midpoints out for inference earlier in this project — they are
            fine for a plot, not for a modelled quantity.
          </Text>
          <Text style={{ color: theme.text.secondary }}>
            Two smaller points. LDL exists only for respondents who fasted 8+
            hours, so requiring it drops us from 3,768 to 3,141, and ABS
            additionally excluded everyone with triglycerides ≥4.5 mmol/L from the
            LDL variable — a non-random exclusion of exactly the most
            dyslipidaemic people. And the clinically standard ratio is total
            cholesterol to HDL, not HDL to LDL.
          </Text>
        </Stack>

        <Stack gap={8}>
          <H3>Are these the same people?</H3>
          <Table
            headers={["Pair of abnormalities", "phi"]}
            rows={[
              ["High total cholesterol & high LDL", "0.771"],
              ["Low HDL & high LDL", "−0.073"],
              ["High total cholesterol & low HDL", "−0.120"],
            ].map(([a, b], i) => [
              <Text size="small">{a}</Text>,
              <Text size="small" weight={i === 0 ? "bold" : "normal"}
                style={{ fontFamily: "monospace", color: i === 0 ? theme.accent.primary : undefined }}>
                {b}
              </Text>,
            ])}
            columnAlign={["left", "right"]}
          />
          <Caption>
            Correlation between binary abnormality flags, n = 3,141 with all
            three measured.
          </Caption>
        </Stack>
      </Grid>

      <Callout tone="warning" title="What this means for the multi-outcome idea">
        <Text size="small">
          The instinct is right but the pairing is wrong. LDL is{" "}
          <Text weight="semibold">0.77 correlated with total cholesterol</Text> —
          nearly the same construct, so adding it buys little while costing 600
          respondents. HDL is the genuinely independent axis, correlating{" "}
          <Text weight="semibold">−0.12</Text> with total cholesterol. So model{" "}
          <Text weight="semibold">total cholesterol and HDL as two separate
          binary outcomes</Text>, drop LDL to a sensitivity analysis, and use
          `CVDMEDST` as the composite instead of building a ratio.
        </Text>
      </Callout>
    </Stack>
  );
}

/* ----------------------------------------------------------- recommendation */

function Recommendation() {
  const theme = useHostTheme();

  const items: Array<[string, string, string]> = [
    [
      "Keep the screening framing",
      "Adopt",
      "Predicting who has undetected dyslipidaemia has a decision-relevant answer and can be evaluated out of sample. Rewording it to 'the association between cholesterol and age, sex and BMI' turns it into a descriptive question whose answer is already established, and our own numbers show that answer would be a weak odds ratio with nothing to act on.",
    ],
    [
      "Swap the outcome to CVDMEDST",
      "Adopt",
      "Untreated dyslipidaemia (n = 1,612) versus no dyslipidaemia (n = 965), using ABS's medication-aware definition instead of self-report. This is the single change that makes the question answerable.",
    ],
    [
      "Model total cholesterol and HDL separately",
      "Adopt, modified",
      "The multi-outcome instinct is correct because HDL and total cholesterol are near-orthogonal. But use two binary outcomes rather than a ratio, and keep LDL as a sensitivity analysis given it is 0.77 correlated with total cholesterol and fasting-restricted.",
    ],
    [
      "Drop the causal language",
      "Reject",
      "'Determine which factor may be causing the high cholesterol' is not available from a cross-sectional survey, and the dietary predictors come from a single 24-hour recall with day-to-day reliability around 0.43. A comparison group does not create causal identification — and it is already inherent to any regression, so no design change is needed.",
    ],
    [
      "Fix the wording without changing the target",
      "Adopt",
      "The objection that 'unrecognised high cholesterol' is confusing is fair, because it conflates undiagnosed, untreated and uncontrolled. CVDMEDST resolves that precisely: say 'adults with abnormal lipid levels who are not receiving lipid-lowering treatment'. That is clearer than the original and clearer than the proposed rewrite.",
    ],
  ];

  return (
    <Stack gap={12}>
      <Label>Recommendation</Label>
      <H2>What to bring to the 8PM review</H2>
      <Stack gap={8}>
        {items.map(([title, verdict, body]) => (
          <div key={title}>
            <Card>
              <CardHeader
                trailing={
                  <Pill
                    size="sm"
                    tone={verdict === "Reject" ? "warning" : "info"}
                    active={verdict !== "Reject"}
                  >
                    {verdict}
                  </Pill>
                }
              >
                {title}
              </CardHeader>
              <CardBody>
                <Text size="small" style={{ color: theme.text.secondary }}>
                  {body}
                </Text>
              </CardBody>
            </Card>
          </div>
        ))}
      </Stack>

      <Divider />

      <Callout tone="neutral" title="One coordination point">
        <Text size="small">
          The plan has the question being finalised at 8PM while feasibility of
          the outcome and predictors is still being checked in parallel. That
          ordering is backwards, and it is why the self-report problem above had
          not surfaced yet. The material here settles feasibility, so the review
          can proceed — but the team should agree that the outcome variable is a
          feasibility question, not a wording question.
        </Text>
      </Callout>
    </Stack>
  );
}

export default function CholesterolFeasibility() {
  return (
    <Stack gap={36} style={{ padding: 28, maxWidth: 1140 }}>
      <Header />
      <SelfReport />
      <Anthropometry />
      <RatioProblem />
      <Recommendation />
    </Stack>
  );
}
