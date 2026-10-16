"""Generate the two .drawio files for the serverless pipeline repo."""
import sys
from html import escape

OUTDIR = sys.argv[1]

C = {"storage": "#7AA116", "integration": "#E7157B", "compute": "#ED7100", "database": "#C925D1",
     "analytics": "#8C4FFF", "management": "#E7157B", "security": "#DD344C", "cost": "#7AA116"}
INK = "#232F3E"
EDGE = "#545B64"
RED = "#D13212"


class Doc:
    def __init__(self, name, w, h):
        self.name, self.w, self.h = name, w, h
        self.cells = []
        self.n = 2
        self.org = {"1": (0, 0)}  # absolute origin of each container; all coordinates passed in are absolute

    def _id(self):
        self.n += 1
        return f"c{self.n}"

    def add(self, value, style, x, y, w, h, parent="1", vertex=True):
        i = self._id()
        value = value.replace("\n", "<br>")
        self.org[i] = (x, y)
        px, py = self.org[parent]
        x, y = x - px, y - py
        self.cells.append(
            f'<mxCell id="{i}" value="{escape(value)}" style="{style}" vertex="1" parent="{parent}">'
            f'<mxGeometry x="{x}" y="{y}" width="{w}" height="{h}" as="geometry"/></mxCell>')
        return i

    def group(self, label, kind, x, y, w, h, parent="1", fs=12):
        styles = {
            "cloud": f"grIcon=mxgraph.aws4.group_aws_cloud_alt;strokeColor={INK};fontColor={INK};dashed=0;",
            "region": "grIcon=mxgraph.aws4.group_region;strokeColor=#00A4A6;fontColor=#147EBA;dashed=1;",
            "account": "grIcon=mxgraph.aws4.group_account;strokeColor=#CD2264;fontColor=#CD2264;dashed=0;",
        }
        st = ("points=[];outlineConnect=0;gradientColor=none;html=1;whiteSpace=wrap;fontSize=%d;fontStyle=1;"
              "container=1;pointerEvents=0;collapsible=0;recursiveResize=0;shape=mxgraph.aws4.group;"
              "fillColor=none;verticalAlign=top;align=left;spacingLeft=30;" % fs) + styles[kind]
        return self.add(label, st, x, y, w, h, parent)

    def box(self, label, x, y, w, h, parent="1", color="#879196", fs=12):
        st = (f"fillColor=none;strokeColor={color};dashed=1;verticalAlign=top;fontStyle=1;fontColor={color};"
              f"whiteSpace=wrap;html=1;align=left;spacingLeft=10;spacingTop=4;fontSize={fs};rounded=1;arcSize=3;container=1;collapsible=0;")
        return self.add(label, st, x, y, w, h, parent)

    @staticmethod
    def lab(pos):
        return {"below": "verticalLabelPosition=bottom;verticalAlign=top;align=center;",
                "above": "verticalLabelPosition=top;verticalAlign=bottom;align=center;",
                "right": "labelPosition=right;verticalLabelPosition=middle;align=left;verticalAlign=middle;spacingLeft=4;",
                "left": "labelPosition=left;verticalLabelPosition=middle;align=right;verticalAlign=middle;spacingRight=4;"}[pos]

    def res(self, label, icon, cat, x, y, parent="1", s=64, fs=12, pos="below"):
        st = (f"sketch=0;outlineConnect=0;fontColor={INK};gradientColor=none;fillColor={C[cat]};strokeColor=#ffffff;"
              f"dashed=0;html=1;fontSize={fs};" + self.lab(pos) +
              f"aspect=fixed;shape=mxgraph.aws4.resourceIcon;resIcon=mxgraph.aws4.{icon};")
        return self.add(label, st, x, y, s, s, parent)

    def shape(self, label, shp, color, x, y, w=52, h=52, parent="1", fs=12, pos="below"):
        st = (f"sketch=0;outlineConnect=0;fontColor={INK};gradientColor=none;fillColor={color};strokeColor=none;"
              f"dashed=0;html=1;fontSize={fs};" + self.lab(pos) +
              f"aspect=fixed;pointerEvents=1;shape=mxgraph.aws4.{shp};")
        return self.add(label, st, x, y, w, h, parent)

    def text(self, label, x, y, w, h, fs=12, bold=False, color=INK, align="left", parent="1"):
        st = (f"text;html=1;strokeColor=none;fillColor=none;align={align};verticalAlign=top;whiteSpace=wrap;"
              f"fontSize={fs};fontColor={color};fontStyle={1 if bold else 0};")
        return self.add(label, st, x, y, w, h, parent)

    def badge(self, n, x, y, parent="1", d=24, fs=12):
        st = (f"ellipse;whiteSpace=wrap;html=1;aspect=fixed;fillColor={INK};strokeColor=none;fontColor=#FFFFFF;"
              f"fontStyle=1;fontSize={fs};")
        return self.add(str(n), st, x, y, d, d, parent)

    def chip(self, label, x, y, w, h, fs=12):
        st = (f"rounded=1;arcSize=50;whiteSpace=wrap;html=1;fillColor=#EAF0F8;strokeColor=#C4D2E6;fontColor=#1F4E9C;"
              f"fontStyle=1;fontSize={fs};")
        return self.add(label, st, x, y, w, h)

    def gh(self, label, x, y, w=150, h=56, parent="1", fs=12):
        st = (f"rounded=1;whiteSpace=wrap;html=1;fillColor={INK};strokeColor=none;fontColor=#FFFFFF;fontStyle=1;"
              f"fontSize={fs};")
        return self.add(label, st, x, y, w, h, parent)

    def edge(self, src, dst, label="", color=EDGE, dashed=False, w=2, ex=None, ey=None, nx=None, ny=None, fs=11, via=None):
        i = self._id()
        st = (f"edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;endArrow=block;endFill=1;strokeColor={color};"
              f"strokeWidth={w};fontSize={fs};fontColor={color};labelBackgroundColor=#FFFFFF;"
              + ("dashed=1;dashPattern=6 4;" if dashed else ""))
        if ex is not None:
            st += f"exitX={ex};exitY={ey};exitDx=0;exitDy=0;"
        if nx is not None:
            st += f"entryX={nx};entryY={ny};entryDx=0;entryDy=0;"
        self.cells.append(
            f'<mxCell id="{i}" value="{escape(label.replace(chr(10), "<br>"))}" style="{st}" edge="1" parent="1" source="{src}" target="{dst}">'
            f'<mxGeometry relative="1" as="geometry">'
            + ('<Array as="points">' + "".join(f'<mxPoint x="{px}" y="{py}"/>' for px, py in via) + '</Array>' if via else "")
            + '</mxGeometry></mxCell>')
        return i

    def xml(self):
        return (f'<mxfile host="drawio"><diagram name="{escape(self.name)}">'
                f'<mxGraphModel dx="0" dy="0" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" '
                f'fold="1" page="1" pageScale="1" pageWidth="{self.w}" pageHeight="{self.h}" background="#FFFFFF" math="0" shadow="0">'
                '<root><mxCell id="0"/><mxCell id="1" parent="0"/>'
                + "".join(self.cells) + "</root></mxGraphModel></diagram></mxfile>")




# =====================================================================
# Landing zone architecture. All coordinates absolute.
# =====================================================================
PINK = "#E7157B"


def acct(doc, label, x, y, w, h, parent):
    return doc.group(label, "account", x, y, w, h, parent=parent, fs=12)


def ou(doc, label, x, y, w, h, parent):
    return doc.box(label, x, y, w, h, parent=parent, color="#7D8998", fs=12)


def scp(doc, text, x, y, w, parent="1", fs=11):
    """An SCP shown the AWS way: the policy icon with a plain label. No tinted box."""
    return doc.shape(text, "policy", PINK, x, y + 3, 18, 18, parent=parent, fs=fs, pos="right")


d = Doc("AWS landing zone", 2100, 1040)
d.add("", "rounded=0;fillColor=#FFFFFF;strokeColor=none;", 0, 0, 2100, 1040)
d.text("Multi-account AWS landing zone", 30, 20, 900, 34, fs=24, bold=True)
d.text("Reference architecture, built as four Terraform stacks", 30, 56, 1000, 22, fs=14, color="#545B64")

people = d.shape("Engineers", "users", INK, 40, 245, 60, 60)
cloud = d.group("AWS Cloud", "cloud", 150, 100, 1580, 910)
org = d.box("AWS Organization  ·  SCPs on root: baseline-guardrails, region-restriction (eu-west-2, eu-west-1 only)",
            180, 150, 1520, 830, parent=cloud, color=PINK, fs=13)

mgmt = d.group("Management account", "account", 210, 200, 1460, 180, parent=org)
orgs = d.res("Organizations\nOU tree, SCPs, tag policy", "organizations", "management", 600, 245, parent=mgmt, s=60, pos="right")
sso = d.res("IAM Identity Center\ntime-limited roles in each account", "single_sign_on", "security", 260, 245, parent=mgmt, s=60, pos="right")
trail = d.res("Organisation CloudTrail\nall accounts, all regions", "cloudtrail", "management", 950, 245, parent=mgmt, s=60, pos="right")
budget = d.res("Budgets\none alert per account", "budgets", "cost", 1300, 245, parent=mgmt, s=60, pos="right")

# OUs
sec = ou(d, "OU: Security", 210, 420, 600, 400, org)
la = acct(d, "log-archive", 230, 465, 270, 330, sec)
logs = d.res("CloudTrail logs (S3)\nObject Lock 365 days\nversioned, deny-delete", "s3", "storage", 335, 545, parent=la, s=60, pos="below")
st = acct(d, "security-tooling", 520, 465, 270, 330, sec)
aa = d.res("Access Analyzer\norg-wide, free", "identity_and_access_management", "security", 545, 520, parent=st, s=50, pos="right")
gd = d.res("GuardDuty\n(switch: off)", "guardduty", "security", 545, 615, parent=st, s=50, pos="right")
sh = d.res("Security Hub\n(switch: off)", "security_hub", "security", 545, 710, parent=st, s=50, pos="right")

inf = ou(d, "OU: Infrastructure", 830, 420, 200, 400, org)
acct(d, "shared-services", 845, 465, 170, 150, inf)
d.text("Networking and CI/CD shared by workloads", 860, 510, 145, 60, fs=11, color="#545B64")

wl = ou(d, "OU: Workloads", 1050, 420, 400, 400, org)
prod = ou(d, "OU: Prod", 1065, 465, 180, 330, wl)
acct(d, "workloads-prod", 1080, 510, 150, 150, prod)
d.text("Developers: read-only", 1092, 560, 130, 40, fs=11, color="#545B64")
nonprod = ou(d, "OU: NonProd", 1255, 465, 180, 330, wl)
acct(d, "workloads-nonprod", 1270, 510, 150, 150, nonprod)
d.text("Developers: build and run", 1282, 560, 130, 40, fs=11, color="#545B64")

sb = ou(d, "OU: Sandbox", 1470, 420, 200, 190, org)
acct(d, "sandbox", 1485, 465, 170, 90, sb)
scp(d, "SCP: sandbox-limits", 1485, 568, 170, parent=sb)
sus = ou(d, "OU: Suspended", 1470, 630, 200, 190, org)
d.text("Accounts being closed", 1490, 680, 160, 20, fs=11, color="#545B64", parent=sus)
scp(d, "SCP: deny-all", 1485, 778, 170, parent=sus)

# Guardrail strip
d.text("Guardrails applied to every account (service control policies)", 210, 850, 900, 20, fs=13, bold=True, parent=org)
for i, t in enumerate(["No leaving the organisation", "CloudTrail cannot be stopped or edited",
                       "Security services cannot be disabled", "Root user denied",
                       "Landing zone role protected", "Only eu-west-2 and eu-west-1"]):
    scp(d, t, 210 + (i % 3) * 300, 885 + (i // 3) * 40, 285, parent=org)
d.text("Every account: one budget alert · Identity Center access only · logs to log-archive", 1150, 890, 520, 60, fs=12, color="#545B64", parent=org)

ci = d.gh("GitHub Actions\nterraform test (19, mocked AWS)\nIAM Access Analyzer · Checkov", 1770, 930, 300, 80)

# edges
d.text("every API call from every account", 990, 318, 260, 20, fs=11, color="#545B64")
d.edge(people, sso, "sign in once", ex=1, ey=0.5, nx=0, ny=0.5)
d.edge(trail, logs, "", color="#545B64", ex=0.5, ey=1, nx=0.5, ny=0, via=[(980, 410), (365, 410)])
d.edge(orgs, st, "delegated\nadmin", color="#DD344C", dashed=True, w=1.5, ex=0.5, ey=1, nx=0.41, ny=0)

lx = 1770
d.text("How it works", lx, 100, 300, 24, fs=15, bold=True)
notes = [
    "Accounts are grouped into OUs by purpose and risk, under one AWS Organization.",
    "Service control policies set rules no account can break, not even its administrators.",
    "One organisation-wide CloudTrail writes to a locked bucket in the log-archive account.",
    "Security services run centrally from the security-tooling account.",
    "People sign in once through IAM Identity Center. No IAM users, no access keys.",
    "Every account has a budget alert. Sandbox is cost-capped by policy.",
    "All of it is Terraform, tested on every push.",
]
y = 136
for n_ in notes:
    d.text(n_, lx, y, 300, 60, fs=12)
    y += 62
d.text("Pink dashed: access and delegation\nGrey: log flow\nPolicy icon: service control policy (SCP)",
       lx, y + 10, 300, 60, fs=12, color="#545B64")

open(f"{OUTDIR}/architecture.drawio", "w").write(d.xml())
print("ok")

# =====================================================================
# LinkedIn: 540x675 page, exported at 2x = 1080x1350.
# Same conventions as the detailed diagram: AWS Cloud group, official icons,
# numbered steps with a legend, labels kept clear of every line.
# =====================================================================
L = Doc("LinkedIn", 540, 675)
L.add("", "rounded=0;fillColor=#FFFFFF;strokeColor=none;", 0, 0, 540, 675)
L.text("Multi-account AWS landing zone", 22, 22, 500, 30, fs=23, bold=True)
L.text("Built with Terraform", 22, 54, 500, 22, fs=14, color="#545B64")

eng = L.shape("Engineers sign in once", "users", INK, 213, 82, 34, 34, fs=11, pos="right")

lcloud = L.group("AWS Cloud", "cloud", 14, 134, 512, 404, fs=11)
lorg = L.box("AWS Organization", 24, 164, 492, 364, parent=lcloud, color=PINK, fs=11)
L.shape("SCPs on root", "policy", PINK, 400, 168, 18, 18, parent=lorg, fs=10, pos="right")

lm = L.group("Management account", "account", 34, 192, 472, 92, parent=lorg, fs=10)
lsso = L.res("Identity\nCenter", "single_sign_on", "security", 212, 224, parent=lm, s=36, fs=10, pos="right")
L.res("Organizations", "organizations", "management", 50, 224, parent=lm, s=36, fs=10, pos="right")
ltrail = L.res("CloudTrail\norg-wide", "cloudtrail", "management", 360, 224, parent=lm, s=36, fs=10, pos="right")

# Security OU
osec = L.box("OU: Security", 34, 298, 150, 218, parent=lorg, color="#7D8998", fs=10)
ala = L.group("log-archive", "account", 42, 322, 134, 88, parent=osec, fs=10)
llogs = L.res("logs, locked\n365 days", "s3", "storage", 128, 352, parent=ala, s=32, fs=10, pos="left")
ast = L.group("security-tooling", "account", 42, 418, 134, 90, parent=osec, fs=10)
for i, (ic, cat) in enumerate([("identity_and_access_management", "security"), ("guardduty", "security"), ("security_hub", "security")]):
    L.res("", ic, cat, 52 + i * 40, 448, parent=ast, s=28)
L.text("Access Analyzer ·\nGuardDuty · Security Hub", 48, 478, 128, 28, fs=9, color="#545B64", parent=ast)

# Workloads OU
owl = L.box("OU: Workloads", 194, 298, 150, 218, parent=lorg, color="#7D8998", fs=10)
L.group("prod", "account", 202, 322, 134, 88, parent=owl, fs=10)
L.text("developers: read-only", 212, 356, 120, 16, fs=10, color="#545B64")
L.group("nonprod", "account", 202, 418, 134, 90, parent=owl, fs=10)
L.text("developers: build", 212, 452, 120, 16, fs=10, color="#545B64")

# Infrastructure + Sandbox OUs
oinf = L.box("OU: Infrastructure", 354, 298, 152, 102, parent=lorg, color="#7D8998", fs=10)
L.group("shared-services", "account", 362, 322, 136, 70, parent=oinf, fs=10)
L.text("networking, CI/CD", 372, 352, 120, 16, fs=10, color="#545B64")
osb = L.box("OU: Sandbox", 354, 410, 152, 106, parent=lorg, color="#7D8998", fs=10)
L.group("sandbox", "account", 362, 434, 136, 74, parent=osb, fs=10)
L.shape("SCP: cost-capped", "policy", PINK, 372, 470, 18, 18, parent=osb, fs=10, pos="right")

# flows
L.edge(eng, lsso, ex=0.5, ey=1, nx=0.5, ny=0, color="#DD344C", dashed=True, w=1.5)
L.edge(ltrail, llogs, ex=0.5, ey=1, nx=0.5, ny=0, via=[(378, 292), (144, 292)])

L.text("Guardrails on every account", 22, 552, 500, 20, fs=13, bold=True)
L.text("No account can leave the organisation, switch off the audit trail, disable the "
       "security tools or use the root user. Only the London and Ireland regions are allowed.",
       22, 574, 496, 40, fs=11)
L.text("github.com/gumagatsby/aws-landing-zone", 22, 640, 400, 20, fs=11, color="#545B64")
open(f"{OUTDIR}/linkedin-architecture.drawio", "w").write(L.xml())
print("ok li")
