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

const SOURCE =
  "Source: ABS Australian Health Survey 2011-13, National Nutrition and Physical Activity Survey Basic CURF (cat. 4324.0.55.002)";

function SectionLabel({ children }: { children: string }) {
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

/* ------------------------------------------------------------------ header */

function Header() {
  const theme = useHostTheme();
  return (
    <Stack gap={10}>
      <Row gap={8} align="center" wrap>
        <Pill size="sm" tone="info" active>
          STAT3888
        </Pill>
        <Pill size="sm">8-script R pipeline</Pill>
        <Pill size="sm">n = 3,421 analysed</Pill>
        <Spacer />
        <Text size="small" style={{ color: theme.text.quaternary }}>
          27 Aug 2026
        </Text>
      </Row>

      <H1>Cardiometabolic health beyond BMI</H1>

      <Text style={{ maxWidth: 860, color: theme.text.secondary }}>
        Three research questions on the Australian Health Survey, anchored to a
        full reproduction of Engelen et al. (2017). The short version: BMI is a
        weak proxy for biomarker-defined cardiometabolic risk, dietary and
        physical-activity variables do not explain the mismatch, and they do not
        improve prediction either — but nothing else the survey measures can
        replace BMI.
      </Text>
    </Stack>
  );
}

/* ------------------------------------------------------------ top-line stats */

function Headline() {
  const theme = useHostTheme();
  return (
    <Stack gap={12}>
      <Grid columns={4} gap={12}>
        <Stat value="0.245" label="Cohen's kappa, BMI vs risk" tone="danger" />
        <Stat value="24.2%" label="Normal-BMI adults at elevated risk" />
        <Stat value="38.1%" label="Adults with obesity at low risk" />
        <Stat value="+0.007" label="AUC gain from diet + PA + SES" tone="warning" />
      </Grid>

      <Card>
        <CardHeader trailing="RQ1 / RQ2 / RQ3">Verdict on each question</CardHeader>
        <CardBody>
          <Stack gap={10}>
            <Row gap={10} align="start">
              <Pill size="sm" tone="deleted" active>
                RQ1
              </Pill>
              <Text style={{ color: theme.text.secondary }}>
                Agreement is <Text weight="semibold">fair at best</Text>. BMI
                category and biomarker risk agree at kappa 0.245. Age
                discriminates better (AUC 0.705) than BMI does (0.688).
              </Text>
            </Row>
            <Divider />
            <Row gap={10} align="start">
              <Pill size="sm" tone="warning" active>
                RQ2
              </Pill>
              <Text style={{ color: theme.text.secondary }}>
                <Text weight="semibold">No dietary or activity variable</Text>{" "}
                distinguishes the phenotypes after adjustment, and no BMI-class
                interaction survives correction. Only age, BMI, smoking and
                self-rated health do.
              </Text>
            </Row>
            <Divider />
            <Row gap={10} align="start">
              <Pill size="sm" tone="warning" active>
                RQ3
              </Pill>
              <Text style={{ color: theme.text.secondary }}>
                <Text weight="semibold">Essentially no improvement.</Text>{" "}
                Twenty-one extra predictors add 0.007 AUC — 13% of what BMI alone
                adds — and almost all of it is smoking.
              </Text>
            </Row>
          </Stack>
        </CardBody>
      </Card>
    </Stack>
  );
}

/* ----------------------------------------------------------- why this anchor */

function Anchor() {
  const theme = useHostTheme();

  const papers: Array<[string, string, string, "info" | "neutral"]> = [
    [
      "Engelen et al. 2017, ANZJPH",
      "ANCHOR · reproduced",
      "The only paper of the six with a cardiometabolic outcome (CVD, T2DM, metabolic syndrome). Same biomedical subsample, same biomarkers, and its covariate block is exactly what RQ2 needs. All 36 published odds ratios fall inside our reproduced intervals.",
      "info",
    ],
    [
      "Lei et al. 2016, Br J Nutr",
      "Largely reproducible",
      "Added-sugar intake and food sources. Her exact n = 8,202 Goldberg-filtered sample was recovered, and total sugars (114.2 g/d, SD 61.8), energy and macronutrients match exactly in all eight age groups. Only her bespoke added-sugar composition database is missing; free sugars matches to within 0.5%.",
      "neutral",
    ],
    [
      "Sui et al. 2017, BMC Nutrition",
      "Partially reproducible",
      "Meat, poultry and fish after mixed-dish disaggregation. Pre-disaggregation fish matches exactly at 26.0 g/day and the totals land within 1-3%, because ABS ships its own disaggregation in the food file. Meat-type detail inside mixed dishes and all nutrient-contribution tables are unrecoverable.",
      "neutral",
    ],
    [
      "Machado et al. 2019, BMJ Open",
      "Partially reproducible",
      "Ultra-processed food and nutrient profiles. The NOVA food-code lookup is unpublished (data availability statement reads 'No data are available') and the recipe file is absent, so the exposure cannot be rebuilt. The DISCFLG discretionary flag proxies it well on seven of eight nutrients.",
      "neutral",
    ],
    [
      "Sui et al. 2017, Public Health Nutrition",
      "Partially reproducible",
      "Meal composition by eating occasion. EATOCC and EATTIMEC are complete, and proportions reproduce within 1-3 points. The 'popular choices' table rests on undocumented manual coding of meat cuts and dish names and is unreproducible in principle.",
      "neutral",
    ],
    [
      "Brand-Miller & Barclay 2017, AJCN",
      "Not reproducible",
      "The added-sugar decline. Every cell of its Table 1 is a 1995-to-2011 change, and the 1995 survey, FAOSTAT, ABS apparent-consumption and proprietary Nielsen sales data are all absent. The 2011-12 endpoint alone reproduces on 18 of 21 checked statistics.",
      "neutral",
    ],
  ];

  return (
    <Stack gap={12}>
      <SectionLabel>Literature anchor</SectionLabel>
      <H2>Why Engelen 2017, and how the other five fit</H2>

      <Text style={{ maxWidth: 860, color: theme.text.secondary }}>
        The decisive reason is not the sample or the covariates. In their Measures
        section Engelen state that waist circumference was used "as a proxy
        measure of abdominal obesity (BMI)" — they{" "}
        <Text weight="semibold">assume</Text> anthropometry stands in for
        cardiometabolic risk. RQ1 tests that assumption directly, which turns a
        reproduction into a contribution. The other five papers are dietary-intake
        description studies: they justify the exposures, not the outcome.
      </Text>

      <Stack gap={8}>
        {papers.map(([title, role, why, tone]) => (
          <div key={title}>
            <Card>
              <CardHeader
                trailing={
                  <Pill size="sm" tone={tone} active={tone === "info"}>
                    {role}
                  </Pill>
                }
              >
                {title}
              </CardHeader>
              <CardBody>
                <Text size="small" style={{ color: theme.text.secondary }}>
                  {why}
                </Text>
              </CardBody>
            </Card>
          </div>
        ))}
      </Stack>

      <Callout tone="success" title="Reproduction accuracy on the anchor">
        All 36 published odds ratios from Engelen Table 2 fall inside our
        reproduced confidence intervals. Ratios of reproduced to published
        estimates range 0.95 to 1.19, with metabolic syndrome the least exact
        because the paper's 1.7 mmol/L triglyceride cut-point falls inside an ABS
        band and cannot be point-identified from the Basic CURF.
      </Callout>

      <Callout tone="info" title="What the reproducibility review changed">
        Two assumptions I had been working under were wrong, both in our favour.
        The food file <Text weight="semibold">does</Text> carry added and free
        sugars per food item (ADDSGGRM, FRESGGRM — they sum to the person-level
        totals to within 0.007 g), and it carries ABS's own Australian Dietary
        Guidelines food-group gram columns, which disaggregate meat out of pizza
        and lasagne without the AUSNUT recipe file. That made a much stronger
        diet exposure available, which is tested in the next section.
      </Callout>
    </Stack>
  );
}

/* ------------------------------------------------------------- the outcome */

function Outcome() {
  const theme = useHostTheme();

  const factors: Array<[string, string, string, string, string]> = [
    ["Raised blood pressure", "≥130/85 mmHg or reported hypertension", "SYSTOL, DIASTOL, HYPBC", "37.4% ± 1.1", "1,598"],
    ["Dysglycaemia", "Glucose >6.0, HbA1c ≥6.0%, or reported diabetes", "GLUCFPD, DIAHBRSK, DIABBC", "12.2% ± 0.6", "547"],
    ["Low HDL", "<1.0 (M) / <1.3 (F) mmol/L", "HDLCHSEX", "22.3% ± 1.1", "794"],
    ["High total cholesterol", "≥5.5 mmol/L", "CHOLNTR", "31.8% ± 1.1", "1,289"],
    ["Elevated liver enzymes", "Abnormal ALT or GGT", "ALTNTR, GGTNTR", "19.2% ± 1.0", "707"],
  ];

  return (
    <Stack gap={12}>
      <SectionLabel>Outcome construction</SectionLabel>
      <H2>A biomarker risk score that excludes adiposity</H2>

      <Text style={{ maxWidth: 860, color: theme.text.secondary }}>
        <Text weight="semibold">Elevated risk</Text> means two or more of five
        factors present. Waist and BMI are excluded by construction, so RQ1 is not
        tautological.
      </Text>

      <Table
        headers={["Risk factor", "Definition", "ABS variables", "Weighted prevalence", "n present"]}
        rows={factors.map(([a, b, c, d, e]) => [
          <Text size="small" weight="semibold">{a}</Text>,
          <Text size="small" style={{ color: theme.text.secondary }}>{b}</Text>,
          <Text size="small" style={{ color: theme.text.tertiary, fontFamily: "monospace" }}>{c}</Text>,
          <Text size="small">{d}</Text>,
          <Text size="small" style={{ color: theme.text.secondary }}>{e}</Text>,
        ])}
        columnAlign={["left", "left", "left", "right", "right"]}
        striped
      />
      <Caption>
        Weighted with the 60 NHMS delete-a-group jackknife replicate weights;
        standard errors from the same. Biomedical adults 18+ with all five markers
        and a measured BMI (n = 3,525).
      </Caption>

      <Grid columns={3} gap={12}>
        <Card>
          <CardHeader>Decision 1 — status flags, not bands</CardHeader>
          <CardBody>
            <Text size="small" style={{ color: theme.text.secondary }}>
              The ABS <Text weight="semibold">*NTR</Text> flags already sit on
              clinical cut-points, so the band-interpolation problem that forced
              the metabolic-syndrome reproduction to be bracketed does not arise
              here.
            </Text>
          </CardBody>
        </Card>
        <Card>
          <CardHeader>Decision 2 — no fasting requirement</CardHeader>
          <CardBody>
            <Text size="small" style={{ color: theme.text.secondary }}>
              LDL, triglycerides and fasting glucose exist only for the ~3,180 who
              fasted 8+ hours. Excluding them from the core score keeps n at{" "}
              <Text weight="semibold">3,525 rather than ~2,950</Text>.
            </Text>
          </CardBody>
        </Card>
        <Card>
          <CardHeader>Decision 3 — adiposity excluded</CardHeader>
          <CardBody>
            <Text size="small" style={{ color: theme.text.secondary }}>
              Neither waist nor BMI enters the score. A seven-marker sensitivity
              version on the fasting subsample gives{" "}
              <Text weight="semibold">kappa 0.195</Text> — slightly worse
              agreement, so the conclusion is not an artefact of marker choice.
            </Text>
          </CardBody>
        </Card>
      </Grid>
    </Stack>
  );
}

/* ------------------------------------------------------------------- RQ1 */

function RQ1() {
  const theme = useHostTheme();

  return (
    <Stack gap={12}>
      <SectionLabel>Research question 1</SectionLabel>
      <H2>How strongly does BMI category agree with biomarker risk?</H2>
      <Text style={{ maxWidth: 860, color: theme.text.secondary }}>
        It does not. Agreement is fair by every conventional benchmark, and the
        mismatch runs in both directions.
      </Text>

      <BarChart
        categories={["Underweight", "Normal", "Overweight", "Obese"]}
        series={[
          { name: "Favourable (0-1 risk factors)", data: [30, 864, 722, 386], tone: "info" },
          { name: "Elevated risk (2+ risk factors)", data: [7, 276, 614, 626], tone: "danger" },
        ]}
        stacked
        height={300}
      />
      <Caption>
        Adults by measured BMI category and biomarker risk status (counts,
        unweighted). Y axis: number of adults. X axis: BMI category. n = 3,525.
      </Caption>

      <Grid columns="3fr 2fr" gap={16} align="start">
        <Stack gap={8}>
          <H3>BMI ≥ 25 as a diagnostic test</H3>
          <Table
            headers={["Metric", "Value", "Reading"]}
            rows={[
              ["Sensitivity", "0.814", "Catches most at-risk adults"],
              ["Specificity", "0.447", "Flags over half of low-risk adults"],
              ["Positive predictive value", "0.528", "A positive result is near a coin flip"],
              ["Negative predictive value", "0.760", "A negative result is more informative"],
              ["Observed agreement", "0.605", "Before chance correction"],
              ["Cohen's kappa", "0.245", "Fair — the headline number"],
              ["Youden's J", "0.261", "Weak overall separation"],
              ["Balanced accuracy", "0.630", "Modest"],
            ].map(([m, v, r], i) => [
              <Text size="small" weight={i === 5 ? "semibold" : "normal"}>{m}</Text>,
              <Text size="small" weight={i === 5 ? "bold" : "normal"}
                style={{ color: i === 5 ? theme.accent.primary : undefined, fontFamily: "monospace" }}>
                {v}
              </Text>,
              <Text size="small" style={{ color: theme.text.tertiary }}>{r}</Text>,
            ])}
            columnAlign={["left", "right", "left"]}
            rowTone={[undefined, undefined, undefined, undefined, undefined, "danger", undefined, undefined]}
          />
        </Stack>

        <Stack gap={8}>
          <H3>Weighted prevalence of elevated risk</H3>
          <Table
            headers={["BMI category", "n", "% elevated"]}
            rows={[
              ["Underweight", "37", "10.0 ± 5.2"],
              ["Normal", "1,140", "18.8 ± 1.9"],
              ["Overweight", "1,336", "42.2 ± 1.8"],
              ["Obese", "1,012", "58.3 ± 2.3"],
            ].map(([a, b, c]) => [
              <Text size="small">{a}</Text>,
              <Text size="small" style={{ color: theme.text.secondary }}>{b}</Text>,
              <Text size="small" style={{ fontFamily: "monospace" }}>{c}</Text>,
            ])}
            columnAlign={["left", "right", "right"]}
          />
          <Caption>
            Survey-weighted percentage with jackknife standard error. Unweighted
            row percentages are higher (24.2% for normal BMI) because the
            biomedical subsample over-represents older adults.
          </Caption>
        </Stack>
      </Grid>

      <Divider />

      <H3>Age out-discriminates both adiposity measures</H3>
      <Grid columns="2fr 3fr" gap={16} align="start">
        <BarChart
          categories={["Age", "Waist", "BMI", "BMI ≥ 25"]}
          series={[{ name: "AUC for elevated risk", data: [0.705, 0.701, 0.688, 0.63] }]}
          height={220}
          horizontal
        />
        <Stack gap={8}>
          <Text style={{ color: theme.text.secondary }}>
            Area under the ROC curve for elevated cardiometabolic risk, each
            predictor taken alone. Age reaches 0.705, waist 0.701, BMI 0.688, and
            BMI dichotomised at 25 drops to 0.630 — dichotomising discards roughly
            a fifth of the usable signal.
          </Text>
          <Callout tone="info" title="This reframes RQ3">
            If age already beats BMI on its own, the "age, sex and BMI" baseline
            is mostly an age model. The interesting question is not what diet adds
            beyond BMI, but what it adds beyond age.
          </Callout>
        </Stack>
      </Grid>
      <Caption>
        X axis: AUC (0.5 = no discrimination). Computed on the same 3,525 adults.
      </Caption>
    </Stack>
  );
}

/* ------------------------------------------------------------------- RQ2 */

function RQ2() {
  const theme = useHostTheme();

  const survivors: Array<[string, string, string]> = [
    ["BMI category", "1.4 × 10⁻⁸", "Obese OR 4.69 (3.37–6.53); Overweight OR 2.44 (1.79–3.33)"],
    ["Age", "9.9 × 10⁻⁸", "OR 2.01 (1.68–2.40) per 16.6-year SD"],
    ["Smoking status", "0.0074", "Current smoker OR 2.52 (1.63–3.88); ex-smoker null"],
    ["Self-rated health", "0.041", "Fair OR 2.78; Poor OR 2.43; Good OR 2.00 vs Excellent"],
  ];

  const nulls: Array<[string, string]> = [
    ["SEIFA quintile", "0.099"],
    ["Sitting time", "0.172"],
    ["Sodium density", "0.185"],
    ["% energy from free sugars", "0.206"],
    ["Occupation", "0.289"],
    ["Sleep duration", "0.405"],
    ["Fruit serves", "0.424"],
    ["Energy intake : BMR", "0.575"],
    ["Fibre density", "0.626"],
    ["% energy from saturated fat", "0.653"],
    ["Physical activity", "0.699"],
    ["Sex", "0.705"],
    ["Vegetable serves", "0.756"],
    ["Education", "0.798"],
  ];

  return (
    <Stack gap={12}>
      <SectionLabel>Research question 2</SectionLabel>
      <H2>What distinguishes normal-BMI adults with elevated risk?</H2>

      <Text style={{ maxWidth: 900, color: theme.text.secondary }}>
        Fitted on the full sample with BMI-class × predictor interactions rather
        than on the normal-BMI stratum alone. That gives{" "}
        <Text weight="semibold">1,487 events instead of 269</Text>, and an
        interaction is the direct test of whether a predictor carries information
        BMI does not already encode. Survey-weighted throughout.
      </Text>

      <H3>Survives Holm correction across 18 predictors</H3>
      <Table
        headers={["Predictor", "Joint Wald p (Holm)", "Effect"]}
        rows={survivors.map(([a, b, c]) => [
          <Text size="small" weight="semibold">{a}</Text>,
          <Text size="small" style={{ fontFamily: "monospace", color: theme.accent.primary }}>{b}</Text>,
          <Text size="small" style={{ color: theme.text.secondary }}>{c}</Text>,
        ])}
        columnAlign={["left", "right", "left"]}
        rowTone={["success", "success", "success", "success"]}
      />

      <H3>Does not — every dietary and activity variable</H3>
      <Grid columns={2} gap={16} align="start">
        <Table
          headers={["Predictor", "Joint p", "Holm"]}
          rows={nulls.map(([a, b]) => [
            <Text size="small">{a}</Text>,
            <Text size="small" style={{ fontFamily: "monospace", color: theme.text.secondary }}>{b}</Text>,
            <Text size="small" style={{ color: theme.text.quaternary }}>1.00</Text>,
          ])}
          columnAlign={["left", "right", "right"]}
          striped
        />
        <Stack gap={10}>
          <Callout tone="warning" title="No interaction survives either">
            The smallest BMI-class interaction p-value is 0.185 (sodium density);
            every Holm-adjusted value is 1.00. Predictors do{" "}
            <Text weight="semibold">not</Text> act differently at normal BMI — the
            answer to the interaction framing is a clean null.
          </Callout>
          <Card>
            <CardHeader>Cross-check against a normal-BMI-only model</CardHeader>
            <CardBody>
              <Text size="small" style={{ color: theme.text.secondary }}>
                The interaction model's normal-BMI simple slopes reproduce a
                genuinely stratified model (n = 1,115, 269 events); ratios of the
                two sets of odds ratios sit between 0.92 and 1.10 for every
                predictor. The pooled model is not hiding stratum-specific
                effects.
              </Text>
            </CardBody>
          </Card>
          <Card>
            <CardHeader>Collinearity fix applied</CardHeader>
            <CardBody>
              <Text size="small" style={{ color: theme.text.secondary }}>
                Total energy correlated 0.89 with the energy-to-BMR ratio (VIF 6.0
                and 5.6 together), inflating the diet block's standard errors. It
                was dropped; nutrients enter as densities per MJ or as percentage
                of energy, and the ratio adjusts for differential under-reporting.
              </Text>
            </CardBody>
          </Card>
        </Stack>
      </Grid>
      <Caption>
        Design-based joint Wald tests from survey-weighted logistic regression,
        Holm-adjusted across the 18-predictor family. n = 3,421.
      </Caption>
    </Stack>
  );
}

/* ------------------------------------------------------------------- RQ3 */

function RQ3() {
  const theme = useHostTheme();

  const models: Array<[string, string, string, string, string, string, "success" | "danger" | "info" | undefined]> = [
    ["M0: age + sex", "2", "0.7036", "−0.0517", "−0.063 to −0.040", "<0.001", "danger"],
    ["M1: + BMI  (baseline)", "3", "0.7550", "—", "—", "—", "info"],
    ["M2: + activity & sleep", "6", "0.7565", "+0.0016", "−0.001 to +0.004", "0.146", undefined],
    ["M3: + diet", "10", "0.7543", "−0.0005", "−0.002 to +0.001", "0.550", undefined],
    ["M4: + socioeconomic", "12", "0.7567", "+0.0019", "−0.001 to +0.005", "0.177", undefined],
    ["M5: + smoking", "5", "0.7598", "+0.0048", "+0.001 to +0.009", "0.013", "success"],
    ["M6: all blocks", "24", "0.7619", "+0.0073", "+0.003 to +0.012", "0.002", "success"],
    ["M7: all except BMI", "23", "0.7213", "−0.0330", "−0.045 to −0.021", "<0.001", "danger"],
  ];

  return (
    <Stack gap={12}>
      <SectionLabel>Research question 3</SectionLabel>
      <H2>Do diet, activity and socioeconomic variables improve prediction?</H2>

      <Text style={{ maxWidth: 900, color: theme.text.secondary }}>
        Elastic-net logistic regression, 20 × 5-fold cross-validation with the
        penalty tuned <Text weight="semibold">inside</Text> each training fold, so
        no test observation influences either the coefficients or the penalty.
      </Text>

      <BarChart
        categories={[
          "M0 age+sex",
          "M1 +BMI",
          "M2 +activity",
          "M3 +diet",
          "M4 +SES",
          "M5 +smoking",
          "M6 all",
          "M7 no BMI",
        ]}
        series={[{ name: "Cross-validated AUC", data: [0.7036, 0.755, 0.7565, 0.7543, 0.7567, 0.7598, 0.7619, 0.7213] }]}
        height={280}
      />
      <Caption>
        Y axis: out-of-sample AUC, mean over 20 cross-validation replicates. X
        axis: nested predictor block. All models predict elevated cardiometabolic
        risk (2+ of five biomarker factors). n = 3,421, 1,487 events (43.5%).
      </Caption>

      <Table
        headers={["Model", "Predictors", "CV AUC", "Δ AUC vs M1", "95% bootstrap CI", "p"]}
        rows={models.map(([m, np, auc, d, ci, p]) => [
          <Text size="small" weight={m.startsWith("M1") ? "bold" : "normal"}>{m}</Text>,
          <Text size="small" style={{ color: theme.text.tertiary }}>{np}</Text>,
          <Text size="small" style={{ fontFamily: "monospace" }}>{auc}</Text>,
          <Text size="small" style={{ fontFamily: "monospace" }}>{d}</Text>,
          <Text size="small" style={{ fontFamily: "monospace", color: theme.text.secondary }}>{ci}</Text>,
          <Text size="small" style={{ fontFamily: "monospace" }}>{p}</Text>,
        ])}
        columnAlign={["left", "right", "right", "right", "right", "right"]}
        rowTone={models.map((m) => m[6])}
      />
      <Caption>
        Uncertainty from a 2,000-resample bootstrap over individuals. Bold row is
        the RQ3 baseline. Green rows improve on it, red rows are worse.
      </Caption>

      <Grid columns={3} gap={12}>
        <Card>
          <CardHeader>What BMI buys</CardHeader>
          <CardBody>
            <Stack gap={4}>
              <Text weight="bold" style={{ fontSize: 20, color: theme.accent.primary }}>
                +0.051
              </Text>
              <Text size="small" style={{ color: theme.text.secondary }}>
                AUC gain from adding BMI to age and sex.
              </Text>
            </Stack>
          </CardBody>
        </Card>
        <Card>
          <CardHeader>What 21 more variables buy</CardHeader>
          <CardBody>
            <Stack gap={4}>
              <Text weight="bold" style={{ fontSize: 20 }}>+0.007</Text>
              <Text size="small" style={{ color: theme.text.secondary }}>
                13.4% of the BMI gain, and mostly smoking (+0.005 of it).
              </Text>
            </Stack>
          </CardBody>
        </Card>
        <Card>
          <CardHeader>Diet block alone</CardHeader>
          <CardBody>
            <Stack gap={4}>
              <Text weight="bold" style={{ fontSize: 20 }}>−0.001</Text>
              <Text size="small" style={{ color: theme.text.secondary }}>
                Indistinguishable from zero (p = 0.55), and slightly negative.
              </Text>
            </Stack>
          </CardBody>
        </Card>
      </Grid>

      <Callout tone="info" title="The productive tension">
        BMI is a weak proxy (kappa 0.245) yet it is not replaceable: 23
        predictors without BMI reach only 0.721 against the baseline's 0.755. The
        survey measures nothing that substitutes for a tape measure and a set of
        scales — which is a more interesting finding than either result alone.
      </Callout>

      <Divider />

      <H3>A methodological correction worth recording</H3>
      <Text style={{ maxWidth: 900, color: theme.text.secondary }}>
        The first pass computed these p-values by pairing AUCs across
        cross-validation replicates, returning values like p = 10⁻⁴⁴. That
        quantity measures fold-assignment noise, which shrinks toward zero as
        replicates are added, so it would certify a difference of any size as
        significant. The reported intervals now come from resampling{" "}
        <Text weight="semibold">individuals</Text>. Under the corrected procedure
        the activity and socioeconomic blocks move from "highly significant" to
        clearly null.
      </Text>
    </Stack>
  );
}

/* ------------------------------------------------------------- robustness */

function Robustness() {
  const theme = useHostTheme();

  const exposures: Array<[string, string, string, string]> = [
    ["Energy density (kcal/g solid food)", "0.815", "0.028", "0.365"],
    ["Dairy (g/MJ)", "0.899", "0.187", "1.00"],
    ["% energy from discretionary food", "0.905", "0.293", "1.00"],
    ["Wholegrain (g/MJ)", "1.066", "0.321", "1.00"],
    ["Red meat (g/MJ)", "0.921", "0.321", "1.00"],
    ["Fish and seafood (g/MJ)", "1.062", "0.411", "1.00"],
    ["Legumes (g/MJ)", "1.059", "0.414", "1.00"],
    ["Refined grain (g/MJ)", "1.053", "0.520", "1.00"],
    ["Poultry (g/MJ)", "0.957", "0.615", "1.00"],
    ["Fruit (g/MJ)", "0.949", "0.666", "1.00"],
    ["Vegetables (g/MJ)", "0.958", "0.754", "1.00"],
    ["Nuts and seeds (g/MJ)", "1.014", "0.868", "1.00"],
    ["Processed meat (g/MJ)", "1.005", "0.940", "1.00"],
  ];

  return (
    <Stack gap={12}>
      <SectionLabel>Robustness test</SectionLabel>
      <H2>The diet null is not an exposure-definition artefact</H2>

      <Text style={{ maxWidth: 900, color: theme.text.secondary }}>
        The obvious objection to RQ2 and RQ3 is that our diet block was thin —
        six nutrient densities and two food-group serves. The reproducibility
        review surfaced two much better exposures already sitting in the Basic
        CURF, so I rebuilt the diet block from the food file and re-ran both
        analyses.
      </Text>

      <Grid columns={2} gap={16} align="start">
        <Card>
          <CardHeader trailing="validated">DISCFLG discretionary flag</CardHeader>
          <CardBody>
            <Text size="small" style={{ color: theme.text.secondary }}>
              Aggregated to a person-level energy share it gives{" "}
              <Text weight="semibold">35.44%</Text>, matching ABS's published
              figure of ~35% exactly, and it tracks the ultra-processed gradient
              in Machado et al. on seven of eight nutrients.
            </Text>
          </CardBody>
        </Card>
        <Card>
          <CardHeader trailing="11 food groups">ADG food-group gram columns</CardHeader>
          <CardBody>
            <Text size="small" style={{ color: theme.text.secondary }}>
              ABS's own mixed-dish disaggregation — it recovers meat from inside
              pizza and lasagne. 18% of all meat grams come from foods outside
              the meat and fish major groups, which a serve variable misses.
            </Text>
          </CardBody>
        </Card>
      </Grid>

      <H3>Thirteen new exposures, none survives correction</H3>
      <Table
        headers={["Food-file exposure", "OR per SD", "p", "p (Holm)"]}
        rows={exposures.map(([lab, or, p, ph]) => [
          <Text size="small">{lab}</Text>,
          <Text size="small" style={{ fontFamily: "monospace" }}>{or}</Text>,
          <Text size="small" style={{ fontFamily: "monospace", color: theme.text.secondary }}>{p}</Text>,
          <Text size="small" style={{ fontFamily: "monospace", color: theme.text.quaternary }}>{ph}</Text>,
        ])}
        columnAlign={["left", "right", "right", "right"]}
        striped
      />
      <Caption>
        Survey-weighted logistic regression, mutually adjusted and additionally
        adjusted for the full original covariate set. n = 3,421.
      </Caption>

      <Grid columns={2} gap={16} align="start">
        <Callout tone="warning" title="Joint test of the whole block">
          <Text size="small">
            F = 1.09 on 13 and 17 degrees of freedom,{" "}
            <Text weight="semibold">p = 0.424</Text>. Adding thirteen
            literature-justified food-file exposures does not improve the model
            at all.
          </Text>
        </Callout>
        <Callout tone="warning" title="And it does not predict either">
          <Text size="small">
            Out-of-sample AUC change against the age + sex + BMI baseline: the
            food-file diet block gives{" "}
            <Text weight="semibold">−0.0007 (p = 0.43)</Text>, and both diet
            blocks together give −0.0001 (p = 0.89).
          </Text>
        </Callout>
      </Grid>

      <H3>Unadjusted prevalence across discretionary-energy quintiles</H3>
      <BarChart
        categories={["Q1 lowest", "Q2", "Q3", "Q4", "Q5 highest"]}
        series={[{ name: "% with elevated cardiometabolic risk", data: [40.73, 44.88, 42.84, 45.61, 43.27] }]}
        height={230}
        valueSuffix="%"
      />
      <Caption>
        Y axis: prevalence of elevated risk (%). X axis: quintile of percentage of
        energy from discretionary food, day-1 recall. Flat, and not an age
        artefact — standardised mean age is within 0.09 SD of the sample mean in
        every quintile. n = 684-685 per quintile.
      </Caption>

      <Callout tone="info" title="Why this strengthens the conclusion">
        Before this test, the null could have been dismissed as a weak exposure
        definition. It now survives ABS's own mixed-dish disaggregation and a
        discretionary-food measure validated against a published
        ultra-processed-food analysis. That isolates measurement error in the
        24-hour recall as the remaining explanation, which is a testable claim
        rather than a shrug.
      </Callout>
    </Stack>
  );
}

/* ------------------------------------------------- measurement / limitations */

function Interpretation() {
  const theme = useHostTheme();

  return (
    <Stack gap={12}>
      <SectionLabel>Interpretation</SectionLabel>
      <H2>These are findings about measurement, not biology</H2>

      <Grid columns="3fr 2fr" gap={16} align="start">
        <Stack gap={10}>
          <Text style={{ color: theme.text.secondary }}>
            A single 24-hour recall attenuates diet–outcome associations severely.
            Our own day-1 / day-2 comparison puts the within-person correlation at
            0.43 for energy and 0.26 for vegetable serves. With reliability that
            low, true associations are biased toward the null by a large and — this
            is the useful part — <Text weight="semibold">quantifiable</Text> factor.
          </Text>
          <Text style={{ color: theme.text.secondary }}>
            The defensible conclusion is that NNPAS-grade dietary data cannot
            detect diet–biomarker associations at this sample size, not that diet
            is unrelated to cardiometabolic risk. The 2,663 respondents here with a
            second-day recall support a measurement-error correction that would put
            a number on the attenuation — turning the weakest part of the story
            into a methods contribution.
          </Text>
        </Stack>

        <Stack gap={8}>
          <H3>Day-1 / day-2 reliability</H3>
          <BarChart
            categories={["Energy", "Fibre", "Sodium", "Veg serves"]}
            series={[{ name: "Pearson r between recall days", data: [0.43, 0.44, 0.30, 0.26] }]}
            height={200}
          />
          <Caption>
            Y axis: correlation between day-1 and day-2 intake. Values near 0.3
            imply severe attenuation of any diet association.
          </Caption>
        </Stack>
      </Grid>

      <H3>Limitations that constrain these claims</H3>
      <Stack gap={8}>
        <Callout tone="warning" title="Circularity constraint on the outcome">
          The blood-pressure and dysglycaemia factors count treated conditions
          (HYPBC, DIABBC), which is standard for metabolic syndrome but means
          self-reported conditions cannot also serve as predictors. The RQ2 and
          RQ3 predictor sets are therefore diet, activity and socioeconomic only.
        </Callout>
        <Callout tone="warning" title="Self-rated health is plausibly a consequence">
          It is one of only four predictors that survives correction in RQ2, but
          people who feel unwell may already know they are unwell. Its association
          should not be read causally.
        </Callout>
        <Callout tone="neutral" title="Weights, bands and design">
          RQ3's cross-validation is unweighted by design — the question is
          individual prediction, not a population mean. Person-level replicate
          weights are absent from the Basic CURF, so full-sample weighted standard
          errors are understated. Biomarkers arrive as ordered bands, and the
          study is cross-sectional, so no causal claims are available.
        </Callout>
      </Stack>
    </Stack>
  );
}

/* ------------------------------------------------------------------ pipeline */

function Pipeline() {
  const theme = useHostTheme();

  const scripts: Array<[string, string, string]> = [
    ["00_setup.R", "Paths, ABS sentinel-code helpers, plot theme", "—"],
    ["01_build_codebook.R", "Parses ABS data-item workbooks into a searchable codebook", "2 CSVs"],
    ["02_verify_data.R", "File inventory, key uniqueness, linkage, sentinel-code audit", "3 tables"],
    ["03_prepare_data.R", "Person-level analysis dataset with labels and derived variables", "npa_person.rds"],
    ["04_eda.R", "Sample characteristics, intake distributions, reliability, biomarker bands", "15 figures"],
    ["05_repro_engelen.R", "Full reproduction of Engelen et al. 2017 Table 2", "36/36 ORs matched"],
    ["06_cmr_outcome.R", "Builds the biomarker risk score and answers RQ1", "3 figures, 5 tables"],
    ["07_rq2_interaction.R", "Survey-weighted models with BMI-class interactions (RQ2)", "3 figures, 6 tables"],
    ["08_rq3_prediction.R", "Nested elastic-net models, repeated CV, bootstrap (RQ3)", "4 figures, 5 tables"],
    ["09_diet_exposure_test.R", "Rebuilds the diet block from the food file and re-tests the nulls", "1 figure, 3 tables"],
  ];

  return (
    <Stack gap={12}>
      <SectionLabel>Reproducibility</SectionLabel>
      <H2>The pipeline</H2>
      <Text style={{ color: theme.text.secondary }}>
        Every number above regenerates from <Text weight="semibold">run_all.R</Text>,
        which executes these in order. All four survey files link to the person
        file with zero orphans across 12,153 respondents.
      </Text>

      <Table
        headers={["Script", "What it does", "Key output"]}
        rows={scripts.map(([s, d, o]) => [
          <Text size="small" style={{ fontFamily: "monospace" }}>{s}</Text>,
          <Text size="small" style={{ color: theme.text.secondary }}>{d}</Text>,
          <Text size="small" style={{ color: theme.text.tertiary }}>{o}</Text>,
        ])}
        striped
      />

      <H3>Sample flow</H3>
      <Grid columns={5} gap={12}>
        <Stat value="12,153" label="Day-1 recall (all persons)" />
        <Stat value="10,178" label="Measured BMI (83.7%)" />
        <Stat value="7,735" label="Day-2 recall (63.6%)" />
        <Stat value="4,444" label="Biomedical (36.6%)" />
        <Stat value="3,421" label="RQ2 / RQ3 analysed" tone="info" />
      </Grid>
      <Caption>{SOURCE}</Caption>
    </Stack>
  );
}

/* --------------------------------------------------------------- next steps */

function NextSteps() {
  const theme = useHostTheme();

  const steps: Array<[string, string, string]> = [
    [
      "Measurement-error correction",
      "Highest value",
      "Use the 2,663 two-day respondents to estimate within-person variance and deattenuate the diet coefficients. Converts the RQ2/RQ3 nulls from a limitation into a quantified result, and is exactly the kind of methods work STAT3888 rewards.",
    ],
    [
      "Re-baseline RQ3 on age alone",
      "Cheap, high payoff",
      "Since age (AUC 0.705) beats BMI (0.688), report increments over age and sex rather than over age, sex and BMI. It is the more honest comparison and follows directly from the RQ1 finding.",
    ],
    [
      "Metabolically healthy obesity as the mirror contrast",
      "Already powered",
      "386 adults are obese with favourable biomarkers. Analysing that cell alongside the 276 normal-weight-at-risk adults tests whether the discordance is symmetric, at no extra data cost.",
    ],
    [
      "Dietary patterns instead of single nutrients",
      "Worth testing",
      "Cluster or PCA on energy-adjusted food-group serves. Patterns are more reliable across recall days than individual nutrients, so this is the one route that might rescue a diet signal.",
    ],
    [
      "Download the free FSANZ AUSNUT 2011-13 food-name file",
      "Cheap unlock",
      "Our codebook has no text labels for any of the 4,712 food codes, so they are currently opaque integers. The FSANZ file is a free public download requiring no ABS approval, and it would let you name every food — recovering meat-type and beverage-type detail for the ~82% of intake that is individually reported rather than inside a mixed dish.",
    ],
  ];

  return (
    <Stack gap={12}>
      <SectionLabel>Where to go next</SectionLabel>
      <H2>Five candidate next steps, in priority order</H2>
      <Stack gap={8}>
        {steps.map(([title, tag, body], i) => (
          <div key={title}>
            <Card>
              <CardHeader
                trailing={
                  <Pill size="sm" tone={i === 0 ? "info" : "neutral"} active={i === 0}>
                    {tag}
                  </Pill>
                }
              >
                {`${i + 1}. ${title}`}
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
    </Stack>
  );
}

/* ------------------------------------------------------------------- page */

export default function STAT3888Findings() {
  return (
    <Stack gap={36} style={{ padding: 28, maxWidth: 1200 }}>
      <Header />
      <Headline />
      <Anchor />
      <Outcome />
      <RQ1 />
      <RQ2 />
      <RQ3 />
      <Robustness />
      <Interpretation />
      <Pipeline />
      <NextSteps />
    </Stack>
  );
}
