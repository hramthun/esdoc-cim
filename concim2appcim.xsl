<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:UML="omg.org/UML1.3"
  exclude-result-prefixes="UML">

  <!-- output an XML file -->
  <xsl:output method="xml" indent="yes"/>

  <!-- ignore free text -->
  <xsl:template match="text()"/>

  <!-- EA outputs XMI v1.1; so this XSL is tailored to that -->
  <!-- strange things might happen at other versions -->
  <xsl:template match="XMI[@xmi.version='1.1']">
    <!-- apply templates to the UML:Model -->
    <!-- and ignore  UML:Diagram, etc. -->
    <xsl:apply-templates select="XMI.content/UML:Model"/>
  </xsl:template> 

  <!-- uh-oh, XMI at a different version -->
  <xsl:template match="XMI">
    <xsl:message terminate="yes">unsupported XMI version</xsl:message>
  </xsl:template>

  <!-- copy appropriate documentation over -->
  <xsl:template match="UML:Class//UML:TaggedValue[@tag='documentation']" mode="class">
    <xsl:call-template name="commentTemplate"/>
  </xsl:template>
  <xsl:template match="UML:Class//UML:TaggedValue[@tag='documentation']" mode="attribute">
    <xsl:call-template name="commentTemplate"/>
  </xsl:template>
  <xsl:template match="UML:Attribute//UML:TaggedValue[@tag='description']" mode="attribute">
    <xsl:call-template name="commentTemplate"/>
  </xsl:template>
  <xsl:template name="commentTemplate">
    <xs:annotation>
      <xs:documentation>
        <xsl:value-of select="@value"/>
      </xs:documentation>
    </xs:annotation>
  </xsl:template>

  <!-- some useful global variables (for strings) -->
  <xsl:variable name="lowerCase">abcdefghijklmnopqrstuvwxyz</xsl:variable>
  <xsl:variable name="upperCase">ABCDEFGHIJKLMNOPQRSTUVWXYZ</xsl:variable>
  <xsl:variable name="built-inTypes">Character CharacterString Integer Real Boolean URI</xsl:variable>
  <xsl:variable name="newline">
    <xsl:text>      
    </xsl:text>
  </xsl:variable>

  <!-- global parameter (passed in from controlling program) -->
  <xsl:param name="xmi_files"/> <!-- the set of XMI files to work with -->

  <!-- convert UML named types to XML named types -->
  <xsl:template name="typeTemplate">
    <xsl:param name="type"/>
    <xsl:if test="$type">
      <xsl:choose>
        <xsl:when test="translate($type,$upperCase,$lowerCase)='characterstring'">
          <xsl:attribute name="type">
            <xsl:text>xs:string</xsl:text>
          </xsl:attribute>
        </xsl:when>
        <xsl:when test="translate($type,$upperCase,$lowerCase)='integer'">
          <xsl:attribute name="type">
            <xsl:text>xs:integer</xsl:text>
          </xsl:attribute>
        </xsl:when>
        <xsl:when test="translate($type,$upperCase,$lowerCase)='real'">
          <xsl:attribute name="type">
            <xsl:text>xs:double</xsl:text>
          </xsl:attribute>
        </xsl:when>
        <xsl:when test="translate($type,$upperCase,$lowerCase)='boolean'">
          <xsl:attribute name="type">
            <xsl:text>xs:boolean</xsl:text>
          </xsl:attribute>
        </xsl:when>
        <xsl:when test="translate($type,$upperCase,$lowerCase)='uri'">
          <xsl:attribute name="type">
            <xsl:text>xs:anyURI</xsl:text>
          </xsl:attribute>
        </xsl:when>
        <xsl:otherwise>
          <xsl:attribute name="type">
            <xsl:value-of select="$type"/>
          </xsl:attribute>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:if>
  </xsl:template>

  <!-- create an XML attribute -->
  <xsl:template name="attributeTemplate">
    <xsl:param name="min"/>
    <xsl:param name="max"/>
    <xsl:param name="type"/>
    <xsl:param name="stereotype"/>
    <xsl:param name="namespace"/>

    <xs:attribute name="{@name}">
      <xsl:attribute name="use">
        <xsl:choose>
          <xsl:when test="$min=0">
            <xsl:text>optional</xsl:text>
          </xsl:when>
          <xsl:otherwise>
            <xsl:text>required</xsl:text>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:attribute>

      <xsl:call-template name="typeTemplate">
        <xsl:with-param name="type" select="$type"/>
      </xsl:call-template>

      <xsl:apply-templates mode="attribute"/>
    </xs:attribute>
  </xsl:template>

  <!-- create a (local) XML element -->
  <xsl:template name="elementTemplate">
    <xsl:param name="min"/>
    <xsl:param name="max"/>
    <xsl:param name="type"/>
    <xsl:param name="stereotype"/>
    <xsl:param name="namespace"/>

    <xsl:element name="xs:element">
      <xsl:attribute name="name">
        <!-- NOT DEALING W/ NAMESPACES -->
        <!--<xsl:value-of select="concat($namespace,':',@name)"/>-->
        <xsl:value-of select="@name"/>
      </xsl:attribute>
      <xsl:attribute name="minOccurs">
        <xsl:value-of select="$min"/>
      </xsl:attribute>
      <xsl:attribute name="maxOccurs">
        <xsl:choose>
          <xsl:when test="string($max)='*'">
            <xsl:text>unbounded</xsl:text>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="$max"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:attribute>

      <xsl:call-template name="typeTemplate">
        <xsl:with-param name="type" select="$type"/>
      </xsl:call-template>


      <xsl:apply-templates mode="attribute"/>
    </xsl:element>
  </xsl:template>

  <!-- create a (global) XML element -->
  <!-- handles the <<document>> stereotype -->
  <xsl:template name="documentTemplate">
    <xsl:param name="namespace"/>
    <!-- document x is just a global element of type complexType x -->
    <xs:element>
      <xsl:attribute name="name">
        <!-- NOT DEALING W/ NAMESPACES -->
        <!--<xsl:value-of
          select="concat($namespace,':',concat(translate(substring(@name,1,1),$upperCase,$lowerCase),substring(@name,2)))"
        />-->
        <xsl:value-of
          select="concat(translate(substring(@name,1,1),$upperCase,$lowerCase),substring(@name,2))"/>

      </xsl:attribute>
      <xsl:attribute name="type">
        <!-- NOT DEALING W/ NAMESPACES -->
        <!--<xsl:value-of select="concat($namespace,':',@name)"/>-->
        <xsl:value-of select="@name"/>
      </xsl:attribute>
      <xsl:apply-templates mode="class"/>
    </xs:element>
  </xsl:template>

  <!-- how to process codelists -->
  <xsl:template name="codelistTemplate">
    <xsl:param name="namespace"/>
    <xs:simpleType>
      <xsl:attribute name="name">
        <!-- NOT DEALING W/ NAMESPACES -->
        <!--<xsl:value-of select="concat($namespace,':',@name)"/>-->
        <xsl:value-of select="@name"/>
      </xsl:attribute>

      <xsl:apply-templates mode="class"/>

      <!-- a codelist is a union of xs:string... -->
      <xs:union>
        <xsl:attribute name="memberTypes">
          <xsl:text>xs:string </xsl:text>
          <!-- NOT DEALING W/ NAMESPACES -->
          <!--<xsl:value-of select="concat($namespace,':',@name,'CodeList')"/>-->
          <xsl:value-of select="concat(@name,'CodeList')"/>
        </xsl:attribute>
      </xs:union>
    </xs:simpleType>
    <xs:simpleType>
      <xsl:attribute name="name">
        <!-- NOT DEALING W/ NAMESPACES -->
        <!--<xsl:value-of select="concat($namespace,':',@name,'CodeList')"/>-->
        <xsl:value-of select="concat(@name,'CodeList')"/>
      </xsl:attribute>


      <!-- ...and an enumeration -->
      <xs:restriction base="xs:string">
        <xsl:for-each select="descendant::UML:Attribute">
          <xsl:sort case-order="lower-first" select="@name"/>
          <xs:enumeration value="{@name}">
            <xsl:apply-templates mode="attribute"/>
          </xs:enumeration>
        </xsl:for-each>
      </xs:restriction>

    </xs:simpleType>
  </xsl:template>

  <!-- how to process enumerations -->
  <xsl:template name="enumerationTemplate">
    <xsl:param name="namespace"/>
    <xs:simpleType>
      <xsl:attribute name="name">
        <!-- NOT DEALING W/ NAMESPACES -->
        <!--<xsl:value-of select="concat($namespace,':',@name)"/>-->
        <xsl:value-of select="@name"/>
      </xsl:attribute>

      <xsl:apply-templates mode="class"/>

      <xs:restriction base="xs:string">
        <xsl:for-each select="descendant::UML:Attribute">
          <xsl:sort case-order="lower-first" select="@name"/>
          <xs:enumeration value="{@name}">
            <xsl:apply-templates mode="attribute"/>
          </xs:enumeration>
        </xsl:for-each>
      </xs:restriction>
    </xs:simpleType>
  </xsl:template>

  <!-- create an XML complexType -->
  <!-- all classes (that aren't codelists or enumerations) are complexTypes -->
  <xsl:template name="complexTypeTemplate">
    <xsl:param name="namespace"/>
    <xsl:param name="id"/>

    <xs:complexType>
      <xsl:attribute name="name">
        <!-- NOT DEALING W/ NAMESPACES -->
        <!--<xsl:value-of select="concat($namespace,':',@name)"/>-->
        <xsl:value-of select="@name"/>
      </xsl:attribute>

      <xsl:apply-templates mode="class"/>

      <!-- check if there are any generalisations that use this class -->
      <xsl:variable name="generalisation" select="//UML:Generalization[@subtype=$id]"/>
      <xsl:if test="$generalisation">
        <xsl:variable name="generalClass"
          select="//UML:Class[@xmi.id=$generalisation/attribute::supertype]"/>
        <!-- have to do this as text b/c I don't close the tags until much later -->
        <xsl:text disable-output-escaping="yes">
          &lt;xs:complexContent&gt;
            &lt;xs:extension base="</xsl:text>
        <xsl:value-of select="$generalClass/attribute::name"/>
        <xsl:text disable-output-escaping="yes">"&gt;
        </xsl:text>
      </xsl:if>

      <xs:sequence>
        <!-- check if any attributes should be elements -->
        <xsl:for-each select="descendant::UML:Attribute">
          <xsl:sort case-order="lower-first" select="@name"/>
          <xsl:variable name="attMin" select="descendant::UML:TaggedValue[@tag='lowerBound']/@value"/>
          <xsl:variable name="attMax" select="descendant::UML:TaggedValue[@tag='upperBound']/@value"/>
          <xsl:variable name="attType" select="descendant::UML:TaggedValue[@tag='type']/@value"/>
          <xsl:variable name="attStereotype"
            select="translate(descendant::UML:TaggedValue[@tag='stereotype']/@value,$upperCase,$lowerCase)"/>

          <!-- A UML attribute is an XML element, unless it is of type x-->
          <!-- where x is an enumeration, codelist, or (certain) built-in type. -->
          <!-- Otherwise it is an XML attribute, -->
          <!-- unless it has an upperBound > 1 -->

          <!-- this convoluted test makes sure that... -->
          <!-- there the upperBound is greater than one -->
          <!-- or it is not an explicit enumeration or codlist or boolean -->
          <!-- or it is not a type which is itself an explicit enumeration or codelist -->
          <xsl:if
            test="$attMax!=1 or 
            ( not($attStereotype='enumeration' or $attStereotype='codelist' or $attType='Boolean' or translate($attType,$upperCase,$lowerCase)='codelist' or translate($attType,$upperCase,$lowerCase)='enumeration')
            and (
            not(
            translate(//UML:Class[@name=$attType]//UML:Stereotype/@name,$upperCase,$lowerCase)='enumeration' 
            or 
            translate(//UML:Class[@name=$attType]//UML:Stereotype/@name,$upperCase,$lowerCase)='codelist') )
            )">
            <xsl:call-template name="elementTemplate">
              <xsl:with-param name="min" select="$attMin"/>
              <xsl:with-param name="max" select="$attMax"/>
              <xsl:with-param name="type" select="$attType"/>
              <xsl:with-param name="stereotype" select="$attStereotype"/>
              <xsl:with-param name="namespace" select="$namespace"/>
            </xsl:call-template>
          </xsl:if>
        </xsl:for-each>

        <!-- check there are any associations which have this class as an endpoint -->
        <xsl:variable name="class" select="."/>
        <xsl:apply-templates
          select="//UML:Association//UML:AssociationEnd[@type=$id]/ancestor::UML:Association"
          mode="association">
          <xsl:sort case-order="lower-first" select="descendant::UML:AssociationEnd[1]/@name"/>
          <xsl:sort case-order="lower-first" select="descendant::UML:AssociationEnd[2]/@name"/>
          <xsl:with-param name="class" select="$class"/>
        </xsl:apply-templates>

      </xs:sequence>
      <!-- ends the section of a complexType where local elements are listed, we can now proceed to local attributes -->

      <!-- check if any attributes should be attributes  -->
      <!-- (should be the inverse of the 1st for-each loop) -->
      <xsl:for-each select="descendant::UML:Attribute">
        <xsl:sort case-order="lower-first" select="@name"/>
        <xsl:variable name="attMin" select="descendant::UML:TaggedValue[@tag='lowerBound']/@value"/>
        <xsl:variable name="attMax" select="descendant::UML:TaggedValue[@tag='upperBound']/@value"/>
        <xsl:variable name="attType" select="descendant::UML:TaggedValue[@tag='type']/@value"/>
        <xsl:variable name="attStereotype"
          select="translate(descendant::UML:TaggedValue[@tag='stereotype']/@value,$upperCase,$lowerCase)"/>

        <!-- this convoluted test is the inverse of that above -->
        <xsl:if
          test="$attMax=1 and 
          ( ($attStereotype='enumeration' or $attStereotype='codelist' or $attType='Boolean' or translate($attType,$upperCase,$lowerCase)='codelist' or translate($attType,$upperCase,$lowerCase)='enumeration')
          or (translate(//UML:Class[@name=$attType]//UML:Stereotype/@name,$upperCase,$lowerCase)='enumeration' or translate(//UML:Class[@name=$attType]//UML:Stereotype/@name,$upperCase,$lowerCase)='codelist')
          )
          ">
          <xsl:call-template name="attributeTemplate">
            <xsl:with-param name="min" select="$attMin"/>
            <xsl:with-param name="max" select="$attMax"/>
            <xsl:with-param name="type" select="$attType"/>
            <xsl:with-param name="stereotype" select="$attStereotype"/>
            <xsl:with-param name="namespace" select="$namespace"/>
          </xsl:call-template>
        </xsl:if>
      </xsl:for-each>

      <!-- don't forget to close any tags from the generalisation -->
      <xsl:if test="$generalisation">
        <xsl:text disable-output-escaping="yes">  
            &lt;/xs:extension&gt;
          &lt;/xs:complexContent&gt;
        </xsl:text>
      </xsl:if>
    </xs:complexType>
  </xsl:template>

  <!-- process associations -->
  <xsl:template match="UML:Association" mode="association">
    <xsl:param name="class"/>

    <!-- I am matching the associationEnd that is _not_ the current class -->
    <!-- b/c UML associations are "backwards" -->

    <xsl:for-each select="descendant::UML:AssociationEnd">
      <xsl:if
        test="(following-sibling::UML:AssociationEnd/@type=$class/attribute::xmi.id) or (preceding-sibling::UML:AssociationEnd/@type=$class/attribute::xmi.id)">
        <!-- bear in mind that sometimes this matches things from other packages -->
        <!-- when dealing w/ a single XMI file, this shows up in XMI.Extensions/EAStub and there's no other reference -->
        <!-- this makes for bad XML; I should deal with a set of XMI files -->
        <xsl:element name="xs:element">
          <xsl:attribute name="name">
            <xsl:choose>
              <xsl:when test="@name">
                <xsl:value-of select="@name"/>
              </xsl:when>
              <xsl:otherwise>
                <!-- this code ensures a class name is camelCase -->
                <xsl:variable name="endType" select="@type"/>
                <xsl:variable name="name" select="//UML:Class[@xmi.id=$endType]/@name"/>
                <xsl:value-of
                  select="concat(translate(substring($name,1,1),$upperCase,$lowerCase),substring($name,2))"
                />
              </xsl:otherwise>
            </xsl:choose>
          </xsl:attribute>
          <!-- work out the max/min of this associationEnd -->
          <xsl:choose>
            <xsl:when test="@multiplicity='*'">
              <xsl:attribute name="minOccurs">1</xsl:attribute>
              <xsl:attribute name="maxOccurs">unbounded</xsl:attribute>
            </xsl:when>
            <xsl:when test="@multiplicity='0'">
              <xsl:attribute name="minOccurs">0</xsl:attribute>
              <xsl:attribute name="maxOccurs">0</xsl:attribute>
            </xsl:when>
            <xsl:when test="@multiplicity='0..*'">
              <xsl:attribute name="minOccurs">0</xsl:attribute>
              <xsl:attribute name="maxOccurs">unbounded</xsl:attribute>
            </xsl:when>
            <xsl:when test="@multiplicity='0..1'">
              <xsl:attribute name="minOccurs">0</xsl:attribute>
              <xsl:attribute name="maxOccurs">1</xsl:attribute>
            </xsl:when>
            <xsl:when test="@multiplicity='1'">
              <xsl:attribute name="minOccurs">1</xsl:attribute>
              <xsl:attribute name="maxOccurs">1</xsl:attribute>
            </xsl:when>
            <xsl:when test="@multiplicity='1..'">
              <xsl:attribute name="minOccurs">1</xsl:attribute>
              <xsl:attribute name="maxOccurs">unbounded</xsl:attribute>
            </xsl:when>
            <xsl:when test="@multiplicity='1..*'">
              <xsl:attribute name="minOccurs">1</xsl:attribute>
              <xsl:attribute name="maxOccurs">unbounded</xsl:attribute>
            </xsl:when>
            <xsl:otherwise>
              <!-- multiplicity is not specified; assume 1..1 -->
              <xsl:attribute name="minOccurs">1</xsl:attribute>
              <xsl:attribute name="maxOccurs">1</xsl:attribute>
            </xsl:otherwise>
          </xsl:choose>

          <!-- work out the type of element -->
          <xsl:attribute name="type">
            <xsl:variable name="type" select="@type"/>
            <xsl:value-of select="//UML:Class[@xmi.id=$type]/@name"/>
          </xsl:attribute>
        </xsl:element>
      </xsl:if>
    </xsl:for-each>

  </xsl:template>

  <!-- every package is a new schema -->
  <!-- TODO: use the document() command to output schemas to separate files -->
  <xsl:template match="UML:Package">
    <!-- NOT DEALING W/ NAMESPACES -->
    <!--<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
      targetNamespace="http://metaforclimate.eu/cim/{@name}">-->
    <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
      <xsl:apply-templates/>
    </xs:schema>
  </xsl:template>

  <!-- every UML class within a package is either a complexType or a simpleType -->
  <!-- <<document>> stereotypes are also global elements -->
  <xsl:template match="UML:Package//UML:Class">

    <xsl:variable name="packageID" select="descendant::UML:TaggedValue[@tag='package']/@value"/>
    <xsl:variable name="classID" select="@xmi.id"/>

    <xsl:variable name="classStereotype"
      select="translate(./UML:ModelElement.taggedValue/UML:TaggedValue[@tag='stereotype']/@value,$upperCase,$lowerCase)"/>
    <xsl:variable name="classNamespace" select="//UML:Package[@xmi.id=$packageID]/@name"/>

    <xsl:choose>
      <xsl:when test="$classStereotype='enumeration'">
        <xsl:call-template name="enumerationTemplate">
          <xsl:with-param name="namespace" select="$classNamespace"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:when test="$classStereotype='codelist'">
        <xsl:call-template name="codelistTemplate">
          <xsl:with-param name="namespace" select="$classNamespace"/>
        </xsl:call-template>
      </xsl:when>

      <!-- if it's not a simpleType (codelist or enumeration) -->
      <!-- then it must be a complexType -->
      <xsl:otherwise>

        <xsl:call-template name="complexTypeTemplate">
          <xsl:with-param name="namespace" select="$classNamespace"/>
          <xsl:with-param name="id" select="$classID"/>
        </xsl:call-template>

      </xsl:otherwise>
    </xsl:choose>
    <xsl:if test="$classStereotype='document'">
      <xsl:call-template name="documentTemplate">
        <xsl:with-param name="namespace" select="$classNamespace"/>
      </xsl:call-template>
    </xsl:if>
  </xsl:template>

</xsl:stylesheet>
