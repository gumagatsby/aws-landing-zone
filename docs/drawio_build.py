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


def scp(doc, text, x, y, w, parent="1"):
    st = ("rounded=1;whiteSpace=wrap;html=1;fillColor=#FDECEA;strokeColor=#D13212;fontColor=#B0281A;"
          "fontSize=11;fontStyle=1;arcSize=20;")
    return doc.add(text, st, x, y, w, 26, parent)


d = Doc("AWS landing zone", 2100, 1040)
d.add("", "rounded=0;fillColor=#FFFFFF;strokeColor=none;", 0, 0, 2100, 1040)
d.text("Multi-account AWS landing zone", 30, 20, 900, 34, fs=24, bold=True)
d.text("Reference architecture · four Terraform stacks · tested without a live organisation", 30, 56, 1000, 22, fs=14, color="#545B64")

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

for n, x, y in [(1, 1660, 160), (2, 178, 846), (3, 935, 230), (4, 515, 455), (5, 245, 230), (6, 1285, 230), (7, 1755, 915)]:
    d.badge(n, x, y)

lx = 1770
d.text("How it works", lx, 100, 300, 24, fs=15, bold=True)
steps = [
    "One AWS Organization. Accounts are grouped into OUs by purpose and risk.",
    "Service control policies set rules no account can break, not even its administrators.",
    "One organisation-wide CloudTrail writes to a locked bucket in the log-archive account.",
    "Security services are run centrally from the security-tooling account.",
    "People sign in once through IAM Identity Center. No IAM users, no access keys.",
    "Every account has a budget alert. Sandbox is cost-capped by policy.",
    "All of it is Terraform, tested on every push without a live organisation.",
]
y = 136
for i, s_ in enumerate(steps, 1):
    d.badge(i, lx, y, d=20, fs=11)
    d.text(s_, lx + 28, y - 2, 270, 64, fs=12)
    y += 70
d.text("Legend", lx, y + 8, 300, 20, fs=13, bold=True)
d.text("Pink dashed: access and delegation\nGrey: log flow\nRed boxes: guardrails (SCPs)",
       lx, y + 30, 300, 60, fs=12, color="#545B64")

open(f"{OUTDIR}/architecture.drawio", "w").write(d.xml())
print("ok")
